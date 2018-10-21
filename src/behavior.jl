immutable IDMMOBILBehavior <: BehaviorModel
	p_idm::IDMParam
	p_mobil::MOBILParam
	idx::Int
end
==(a::IDMMOBILBehavior,b::IDMMOBILBehavior) = (a.p_idm==b.p_idm) && (a.p_mobil==b.p_mobil)
Base.hash(a::IDMMOBILBehavior,h::UInt64=zero(UInt64)) = hash(a.p_idm,hash(a.p_mobil,h))

+(a::IDMMOBILBehavior, b::IDMMOBILBehavior) = IDMMOBILBehavior(a.p_idm+b.p_idm, a.p_mobil+b.p_mobil, 0)
-(a::IDMMOBILBehavior, b::IDMMOBILBehavior) = a+(-1.0*b)
*(a::Real, b::IDMMOBILBehavior) = IDMMOBILBehavior(a*b.p_idm, a*b.p_mobil, 0)
.*(a::Real, b::IDMMOBILBehavior) = a*b
.*(b::IDMMOBILBehavior, v::Vector{Float64}) = IDMMOBILBehavior(b.p_idm.*v[1:6], b.p_mobil.*v[7:9], 0)
^(b::IDMMOBILBehavior, p::Integer) = IDMMOBILBehavior(b.p_idm.^p, b.p_mobil.^p, 0)
.^(b::IDMMOBILBehavior, p::Integer) = IDMMOBILBehavior(b.p_idm.^p, b.p_mobil.^p, 0)
.-{B<:BehaviorModel}(v::Vector{B}, b::IDMMOBILBehavior) = B[v[i]-b for i in 1:length(v)]
/(b::IDMMOBILBehavior, f::Real) = 1/f*b
sqrt(b::IDMMOBILBehavior) = IDMMOBILBehavior(sqrt(b.p_idm), sqrt(b.p_mobil), 0)
zero(::Type{IDMMOBILBehavior}) = IDMMOBILBehavior(zero(IDMParam), zero(MOBILParam), 0)
nan(::Type{IDMMOBILBehavior}) = IDMMOBILBehavior(nan(IDMParam), nan(MOBILParam), 0)
abs(b::IDMMOBILBehavior) = IDMMOBILBehavior(abs(b.p_idm), abs(b.p_mobil), 0)
max(a::IDMMOBILBehavior, b::IDMMOBILBehavior) = IDMMOBILBehavior(max(a.p_idm, b.p_idm), max(a.p_mobil, b.p_mobil), 0)

function IDMMOBILBehavior(s::AbstractString,v0::Float64,s0::Float64,idx::Int)
	return IDMMOBILBehavior(IDMParam(s,v0,s0), MOBILParam(s), idx)
end

typical_velocity(b::IDMMOBILBehavior) = b.p_idm.v0

gen_accel(bmodel::BehaviorModel, dmodel::AbstractMLDynamicsModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG) = error("Uninstantiated Behavior Model")

gen_lane_change(bmodel::BehaviorModel, dmodel::AbstractMLDynamicsModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG) = error("Uninstantiated Behavior Model")

function gen_accel(bmodel::IDMMOBILBehavior, dmodel::AbstractMLDynamicsModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG)

    d = accel_dist(bmodel, dmodel, s, neighborhood, idx)
    acc = rand(rng, d)

    return max(acc, -dmodel.phys_param.brake_limit)
end

function accel_dist(bmodel::IDMMOBILBehavior, dmodel::AbstractMLDynamicsModel, s::MLState, neighborhood::Array{Int,1}, idx::Int)
	pp = dmodel.phys_param
	dt = pp.dt
	car = s.cars[idx]
	vel = car.vel

	dv, ds = get_dv_ds(pp,s,neighborhood,idx,2)

	dvel = get_idm_dv(bmodel.p_idm,dt,vel,dv,ds) #call idm model
    acc = dvel/dt
#=
    if acc > (1.01*bmodel.p_idm.a)
      print(acc)
	  print(" || ")
	  println(bmodel.p_idm.a)
	  warn("acc is bigger than the settle value")
	end
=#
    @assert acc <= 1.01*bmodel.p_idm.a

    @if_debug if ds < 0.0
        Gallium.@enter accel_dist(bmodel, dmodel, s, neighborhood, idx)
    end
    #@assert ds >= 0.0 # can get rid of this
    if neighborhood[2] > 0
        @assert abs(s.cars[neighborhood[2]].vel - (vel-dv)) < 0.0001
    end

    max_safe = max_safe_acc(ds, vel, vel-dv, pp.brake_limit, dt)
	#max_safe = nullable_max_safe_acc(ds, vel, vel-dv, pp.brake_limit, dt)

    # if T, a, and b are small the idm may command something faster than the max_safe
    # @assert max_safe >= acc "max_safe=$max_safe; acc=$acc"
    if acc > max_safe
        acc = max_safe
    end

    lower_bound = min(-1e-5, max(-bmodel.p_idm.a/2, -pp.brake_limit-acc))
    upper_bound = min(bmodel.p_idm.a/2, max(max_safe-acc, 1e-5))

	if lower_bound > upper_bound
		lower_bound = -0.1
		upper_bound = 0.1
	end

	if acc > 8
		acc = 8
	end
	if acc<-8
		acc = -8
	end
	
    return TriangularDist(acc+lower_bound, acc+upper_bound, acc)
end

function max_accel(bmodel::IDMMOBILBehavior)
    return 1.5*bmodel.p_idm.a
end

function gen_lane_change(bmodel::IDMMOBILBehavior, dmodel::AbstractMLDynamicsModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG)
    #print("LC2")
	pp = dmodel.phys_param
	dt = pp.dt
	car = s.cars[idx]
	lane_change = car.lane_change #this is a velocity in the y direction in LANES PER SECOND
	lane_ = car.y

	if mod(lane_-0.5,1) == 0. #in between lanes
        @assert lane_change != 0
		#println("in")
		return lane_change
	end

	#sample normally
	lanechange_::Int = get_mobil_lane_change(bmodel, pp, s, neighborhood, idx, rng)
	#gives +1, -1 or 0

    lanechange = lanechange_
    #println(lanechange * dmodel.lane_change_rate)
	return lanechange * dmodel.lane_change_rate
end

#############################################################################
#TODO How to make compatible with MOBIL?

type AvoidModel <: BehaviorModel
	jerk::Bool
end
AvoidModel() = AvoidModel(false)
# NOTE: JerkModel might be better modeled by a /very/ aggressive IDM car
JerkModel() = AvoidModel(true)
==(a::AvoidModel, b::AvoidModel) = (a.jerk == b.jerk)
Base.hash(a::AvoidModel, h::UInt64=zero(UInt64)) = hash(a.jerk,h)

function closest_car(dmodel::IDMMOBILModel, s::MLState, nbhd::Array{Int,1}, idx::Int, lookahead_only::Bool)
	x = s.cars[idx].x
    y = s.cars[idx].y
	dy = dmodel.phys_param.w_lane

	closest = 0
	min_dist = Inf

	for i = 1:3 #front cars
		if nbhd[i] == 0
			continue
		end
		dist = norm([x - car.x; (y - car.y)*dy])
		if dist < min_dist
			min_dist = dist
			closest = i
		end
	end

	if lookahead_only
		return closest
	end

	for i = 4:6 #rear cars
		if nbhd[i] == 0
			continue
		end
		car = s.cars[nbhd[i]]
		dists = norm([x - car.x; (y - car.y)*dy])
		if dist < min_dist
			min_dist = dist
			closest = i
		end
	end

	return closest

end

function gen_accel(bmodel::AvoidModel, dmodel::IDMMOBILModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG)
	closest_car = closest_car(dmodel,s,neighborhood,idx,bmodel.jerk)
	if closest_car == 0
		return 0.
	end

	x = s.cars[idx].x
	cc = s.cars[closest_car]

	if p.jerk #TODO fix this so it doesn't always accelerate if there's no space
        accel = cs.x - x > 2*dmodel.phys_param.l_car ? 1 : -3. #slam brakes
    else
        accel = -sign(cs.x - x)
    end

	return accel*dmodel.phys_param.dt #XXX times accel interval?

end

function gen_lane_change(bmodel::AvoidModel, dmodel::IDMMOBILModel, s::MLState, neighborhood::Array{Int,1}, idx::Int, rng::AbstractRNG)


	closest_car = closest_car(dmodel,s,neighborhood,idx,bmodel.jerk)
    println("L-C1")
	if closest_car == 0
		return 0.
	end

	pos = s.cars[idx].y
	cc = s.cars[closest_car]

	lanechange = -sign(cc.y - pos)
	#if same lane, go in direction with more room
	if lanechange == 0
		if pos >= 2*dmodel.phys_param.nb_lanes - 1 - pos >= pos #more room to left >= biases to left
			lanechange = 1
		else
			lanechange = -1
		end
	end
	if lanechange > 0 && pos >= 2*dmodel.phys_param.nb_lanes - 1
		lanechange = 0
	elseif lanechange < 0 && pos <= 1
		lanechange = 0
	end

	return lanechange
end
