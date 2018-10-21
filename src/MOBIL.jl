#MOBIL.jl
#A separate file for all the MOBIL stuff

###############
##MOBIL Model##
###############

immutable MOBILParam
	p::Float64 #politeness factor
	b_safe::Float64 #safe braking value
	a_thr::Float64 #minimum accel
	#db::Float64 #lane bias #we follow the symmetric/USA lane change rule
end #MOBILParam
MOBILParam(;p::Float64=0.25,b_safe::Float64=4.,a_thr::Float64=0.2) = MOBILParam(p,b_safe,a_thr)
==(a::MOBILParam,b::MOBILParam) = (a.p==b.p) && (a.b_safe==b.b_safe) && (a.a_thr == b.a_thr)
Base.hash(a::MOBILParam,h::UInt64=zero(UInt64)) = hash(a.p,hash(a.b_safe,hash(a.a_thr,h)))

+(a::MOBILParam, b::MOBILParam) = MOBILParam(a.p+b.p, a.b_safe+b.b_safe, a.a_thr+b.a_thr)
-(a::MOBILParam, b::MOBILParam) = a+(-1.0*b)
*(a::Real, p::MOBILParam) = MOBILParam(a*p.p, a*p.b_safe, a*p.a_thr)
.*(p::MOBILParam, v::Vector{Float64}) = MOBILParam(v[1]*p.p, v[2]*p.b_safe, v[3]*p.a_thr)
.^(p::MOBILParam, n::Real) = MOBILParam(p.p^n, p.b_safe^n, p.a_thr^n)
sqrt(p::MOBILParam) = MOBILParam(sqrt(p.p), sqrt(p.b_safe), sqrt(p.a_thr))
zero(::Type{MOBILParam}) = MOBILParam(0.0, 0.0, 0.0)
nan(::Type{MOBILParam}) = MOBILParam(NaN, NaN, NaN)
abs(p::MOBILParam) = MOBILParam(abs(p.p), abs(p.b_safe), abs(p.a_thr))
max(a::MOBILParam, b::MOBILParam) = MOBILParam(max(a.p,b.p), max(a.b_safe, b.b_safe), max(a.a_thr, b.a_thr))

function MOBILParam(s::AbstractString)
	#typical politeness range: [0.0,0.5]
	typedict = Dict{AbstractString,Float64}("cautious"=>0.5,"normal"=>0.25,"aggressive"=>0.0)
	p = get(typedict,s,-1.)
	assert(p >= 0.)
	return MOBILParam(p=p)
end

function is_lanechange_dangerous(pp::PhysicalParam, s::MLState, nbhd::Array{Int,1}, idx::Int, dir::Real)

	#check if dir is oob
	dt = pp.dt
	lane_ = s.cars[idx].y + dir * dt # XXX this line is the issue!!!

	if (lane_ > pp.nb_lanes) || (lane_ < 1.)
		return true
	end
	#check if will hit car next to you?
	l_car = pp.l_car

	dvlf, slf = get_dv_ds(pp,s,nbhd,idx,round(Int, 5+sign(dir)))
	dvlb, slb = get_dv_ds(pp,s,nbhd,idx,round(Int, 2+sign(dir)))

	#distance at next time step
	#dv ref: ahead: me - him; behind: him - me
	#ds ref: ahead: him - me - l_car; behind: me - him - l_car
	dslf = slf-dvlf*dt
	dslb = slb-dvlb*dt
	diff = 0.0 #something >=0--the safety distance

	return (slf < diff*l_car) || (slb < diff*l_car) || dslb < diff*l_car ||
				dslf < diff*l_car

end

function get_neighborhood(pp::PhysicalParam,s::Union{MLState,MLObs},idx::Int)
	nbhd = zeros(Int,6)
	dists = Inf*ones(6)
	"""
	Each index corresponds to the index (in the car state) that corresponds to
	the position, 0 if there is no such car
	indices:
	6      |     3
	5    |car|   2 ->
	4      |     1
	where 1/2/3 is the front, 3/6 is left

    Note: The same car can occupy two spots if the vehicle is changing lanes.
	"""

	x = s.cars[idx]
	#rightmost lane: no one to the right
	if x.y <= 1.
		dists[[1;4]] = [-1.;-1.]
	#leftmost lane: no one to the left
	elseif x.y >= pp.nb_lanes
		dists[[3;6]] = [-1.;-1.]
	end

	for (i,car) in enumerate(s.cars)
		#i am not a neighbor
		if i == idx
			continue
		end
		pos = car.x
		lane = car.y

        @assert pos >= 0. # this should never happen

		dlane = lane - x.y #NOTE float: convert to int
		#too distant to be a neighbor
		# if abs(dlane) > 2.
		if abs(dlane) >= 2. # changed august 13 - don't remember why this was > 2
			continue
		# elseif abs(dlane) <= 0.5 # this is now handled below in the overlap section
		# 	dlane = 0
		else
			dlane = convert(Int,sign(dlane))
		end

		d = pos-x.x

		offset = d >= 0. ? 2 : 5

		if abs(d) < dists[offset+dlane]
			dists[offset+dlane] = abs(d)
			nbhd[offset+dlane] = i
		end

        if occupation_overlap(car.y, x.y) && abs(d) < dists[offset]
            dists[offset] = abs(d)
            nbhd[offset] = i
        end
	end

	return nbhd
end

function get_dv_ds(pp::PhysicalParam,s::MLState,nbhd::Array{Int,1},idx::Int,idy::Int)
	"""
	idx is the car from whom the perspective is
	idy is the other car
	"""
	car = s.cars[idx]
	nbr = nbhd[idy]
	#dv: if ahead: me - him; behind: him - me
	dv = nbr != 0 ? -1*sign((idy-3.5))*(car.vel - s.cars[nbr].vel) : 0. #XXX What is idy doing here??? (Zach, 7/13/16)
	ds = nbr != 0 ? abs(s.cars[nbr].x - car.x) - pp.l_car : 1000.

	return dv::Float64, ds::Float64
end

"""
Return two numbers first if the lane change is made, second if the lane change is not made

(I think) - Zach (7/13/16)
"""
function get_rear_accel(pp::PhysicalParam,s::MLState,nbhd::Array{Int,1},idx::Int,dir::Int)

	#there is no car behind in that spot
	if nbhd[5+dir] == 0
		return 0.::Float64, 0.::Float64
	end

	v = s.cars[idx].vel

	#behind - me
	dv_behind, s_behind = get_dv_ds(pp,s,nbhd,idx,5+dir)
	v_behind = v - dv_behind

	#me - front
	#what would the relative velocity, distance be if idx wasn't there
	dv_behind_, s_behind_ = get_dv_ds(pp,s,nbhd,idx,2+dir)
	dv_behind_ += dv_behind
	s_behind_ += s_behind + pp.l_car

	dt = pp.dt
	#TODO generalize to get_dv?
	if !(typeof(s.cars[nbhd[5+dir]].behavior) <: IDMMOBILBehavior)
		# assume some default idm model TODO
		behind_idm = IDMParam("normal",31.,4.)
	else
		behind_idm = s.cars[nbhd[5+dir]].behavior.p_idm
	end
	a_follower = get_idm_dv(behind_idm,dt,v_behind,dv_behind,s_behind)/dt #distance behind is a negative number
	a_follower_ = get_idm_dv(behind_idm,dt,v_behind,dv_behind_,s_behind_)/dt

	return a_follower::Float64, a_follower_::Float64
end

# should return a float
function get_mobil_lane_change(behavior, pp::PhysicalParam,s::MLState,nbhd::Array{Int,1},idx::Int,rng::AbstractRNG=MersenneTwister(123))
	#TODO: catch if the parameters don't exist

	#need 6 distances: distance to person behind me, ahead of me
	#				potential distance to person behind me, ahead of me
	#				in other lane(s)
	#need sets of idm parameters
	dt = pp.dt
	state = s.cars[idx]
	p_idm_self = behavior.p_idm
	p_mobil = behavior.p_mobil
	#println(neighborhood)
	if sum(nbhd) == 0
		return 0. #no reason to change lanes if you're all alone
	end
	##if between lanes, return +1 if moving left, -1 if moving right
	if !isinteger(state.y)
		return state.lane_change #continue going in the direction you're going
	end

	v = state.vel
	#get predicted and potential accelerations

	#TODO generalize to get_dv()? # btw this takes a lot of processing time # should we cache?
    dv2, ds2 = get_dv_ds(pp,s,nbhd,idx,2)
    dv3, ds3 = get_dv_ds(pp,s,nbhd,idx,3)
    dv1, ds1 = get_dv_ds(pp,s,nbhd,idx,1)
	a_self = get_idm_dv(p_idm_self,dt,v,dv2,ds2)/dt
	a_self_left = get_idm_dv(p_idm_self,dt,v,dv3,ds3)/dt
	a_self_right = get_idm_dv(p_idm_self,dt,v,dv1,ds1)/dt

	a_follower, a_follower_ = get_rear_accel(pp,s,nbhd,idx,0)
	a_follower_left_, a_follower_left = get_rear_accel(pp,s,nbhd,idx,1)
	a_follower_right_, a_follower_right = get_rear_accel(pp,s,nbhd,idx,-1)

	#calculate incentives
	left_crit = a_self_left-a_self+p_mobil.p*(a_follower_left_-a_follower_left+a_follower_-a_follower)
	right_crit = a_self_right-a_self+p_mobil.p*(a_follower_right_-a_follower_right+a_follower_-a_follower)

	#check safety criterion, also check if there is physically space
	if (a_follower_right_ < -p_mobil.b_safe) && (a_follower_left_ < -p_mobil.b_safe)
		return 0. #neither safe
	end
	if is_lanechange_dangerous(pp,s,nbhd,idx,1) || (a_follower_left_ < -p_mobil.b_safe)
		left_crit = -Inf
	end

	if is_lanechange_dangerous(pp,s,nbhd,idx,-1) || (a_follower_right_ < -p_mobil.b_safe)
		right_crit = -Inf
	end

	#check if going left or right is preferable
    if left_crit >= right_crit
        dir_flag = 1
    else
        dir_flag = -1
    end

	#check incentive criterion
	#if max(left_crit,right_crit) > p_mobil.a_thr
    #=
	if max(abs(left_crit),abs(right_crit)) > p_mobil.a_thr
        println("LCMOBIL")
		return float(dir_flag)
	end
    =#
	if max(left_crit,right_crit) > p_mobil.a_thr
		#println("LCMOBIL")
		return float(dir_flag)
	end
	return 0.
end
