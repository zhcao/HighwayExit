#######################
##Physical Parameters##
#######################

type PhysicalParam
	dt::Float64
	w_car::Float64
	l_car::Float64
	v_nominal::Float64
	w_lane::Float64
	y_interval::Float64
	v_fast::Float64
	v_slow::Float64
	v_med::Float64
	v_max::Float64
	v_min::Float64
	nb_env_cars::Int # maximum
    nb_lanes::Int
	lane_length::Float64
	function PhysicalParam(nb_lanes::Int;dt::Float64=0.75,
							w_car::Float64=2.,
							l_car::Float64=4.,
							v_nominal::Float64=31.,
							w_lane::Float64=4.,
							y_interval::Float64=2.,
							v_fast::Float64=35.,
							v_slow::Float64=27.,
							v_med::Float64=31.,
							nb_vel_bins::Int=100,
							nb_env_cars::Int=1,
							lane_length::Float64=12.,
							v_max::Float64=v_fast+0.,
							v_min::Float64=v_slow-0.)

		assert(v_fast >= v_med)
		assert(v_med >= v_slow)
		assert(v_fast > v_slow)
		self = new()
		self.dt = dt
		self.w_car = w_car
		self.l_car = l_car
		self.v_nominal = v_nominal
		self.w_lane = w_lane
		self.y_interval = y_interval
		self.v_fast = v_fast
		self.v_slow = v_slow
		self.v_med = v_med
		self.v_max = v_max
		self.v_min = v_min
		self.nb_env_cars = nb_env_cars
        self.nb_lanes = nb_lanes
		self.lane_length = lane_length

		return self
		end
end
