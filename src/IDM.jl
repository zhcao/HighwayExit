#IDM.jl
#A separate file for all the IDM stuff

#############
##IDM Model##
#############

immutable IDMParam
	a::Float64 #max  comfy acceleration
	b::Float64 #max comfy brake speed
	T::Float64 #desired safety time headway
	v0::Float64 #desired speed
	s0::Float64 #minimum headway (e.g. if x is less than this then you crashed)
	del::Float64 #'accel exponent'
end #IDMParam
==(a::IDMParam,b::IDMParam) = (a.a==b.a) && (a.b==b.b) &&(a.T == b.T)&&(a.v0==b.v0)&&(a.s0==b.s0)&&(a.del==b.del)
Base.hash(a::IDMParam,h::UInt64=zero(UInt64)) = hash(a.a,hash(a.b,hash(a.T,hash(a.v0,hash(a.s0,hash(a.del,h))))))

+(a::IDMParam, b::IDMParam) = IDMParam(a.a+b.a, a.b+b.b, a.T+b.T, a.v0+b.v0, a.s0+b.s0, a.del+b.del)
-(a::IDMParam, b::IDMParam) = a+(-1.0*b)
*(a::Real, p::IDMParam) = IDMParam(a*p.a, a*p.b, a*p.T, a*p.v0, a*p.s0, a*p.del)
# .*(p::IDMParam,a::Float64) = a*p
.*(p::IDMParam, v::Vector{Float64}) = IDMParam(v[1]*p.a, v[2]*p.b, v[3]*p.T, v[4]*p.v0, v[5]*p.s0, v[6]*p.del)
.^(p::IDMParam, n::Real) = IDMParam(p.a^n, p.b^n, p.T^n, p.v0^n, p.s0^n, p.del^n)
sqrt(p::IDMParam) = IDMParam(sqrt(p.a), sqrt(p.b), sqrt(p.T), sqrt(p.v0), sqrt(p.s0), sqrt(p.del))
zero(::Type{IDMParam}) = IDMParam(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
nan(::Type{IDMParam}) = IDMParam(NaN, NaN, NaN, NaN, NaN, NaN)
abs(p::IDMParam) = IDMParam(abs(p.a), abs(p.b), abs(p.T), abs(p.v0), abs(p.s0), abs(p.del))
max(a::IDMParam, b::IDMParam) = IDMParam(max(a.a,b.a), max(a.b,b.b), max(a.T,b.T), max(a.v0,b.v0), max(a.s0,b.s0), max(a.del,b.del))

function get_idm_s_star(p::IDMParam, v::Float64, dv::Float64)
    return p.s0 + max(0.,v*p.T+v*dv/(2*sqrt(p.a*p.b)))
end

# dv is positive if vehicles are closing
function get_idm_dv(p::IDMParam,dt::Float64,v::Float64,dv::Float64,s::Float64)
	s_ = get_idm_s_star(p, v, dv)
    dvdt = p.a*(1.-(v/p.v0)^p.del - (s_/s)^2)
  if (dvdt) > 1.01*p.a
	  print(p.a)
	  print(" || ")
	  print((v/p.v0)^p.del)
	  print(" || ")
	  println(dvdt)
  end
	#dvdt = min(max(dvdt,-p.b),p.a)
	return (dvdt*dt)::Float64
end #get_idm_dv

# these aren't used anymore, but need to be there for the tests
IDMParam(a::Float64,b::Float64,T::Float64,v0::Float64,s0::Float64;del::Float64=4.) = IDMParam(a,b,T,v0,s0,del)
function build_cautious_idm(v0::Float64,s0::Float64)
	T = 2.
	a = 1.
	b = 1.
	return IDMParam(a,b,T,v0,s0)
end

function build_aggressive_idm(v0::Float64,s0::Float64)
	T = 0.8
	a = 2.
	b = 2.
	return IDMParam(a,b,T,v0,s0)
end

function build_normal_idm(v0::Float64,s0::Float64)
	T = 1.4
	a = 1.5
	b = 1.5
	return IDMParam(a,b,T,v0,s0)
end

#TODO: use Enum or something to avoid misspelling errors
function IDMParam(s::AbstractString,v0::Float64,s0::Float64)
	if lowercase(s) == "cautious"
		return build_cautious_idm(v0,s0)
	elseif lowercase(s) == "normal"
		return build_normal_idm(v0,s0)
	elseif lowercase(s) == "aggressive"
		return build_aggressive_idm(v0,s0)
	else
		error("No such idm phenotype: \"$(s)\"")
	end
end
