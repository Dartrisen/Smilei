# ---------------------------------------------
# SIMULATION PARAMETERS FOR THE PIC-CODE SMILEI
# ---------------------------------------------

import math
L0 = 2.*math.pi # conversion from normalization length to wavelength


Main(
    geometry = "1d3v",

    interpolation_order = 2,

    number_of_patches = [ 4 ],

    timestep = 50 * L0,
    sim_time = 2000 * L0,


    time_fields_frozen = 100000000000.,

    cell_length = [5.*L0],
    sim_length = [160.*L0],

    bc_em_type_x = ["periodic"],


    random_seed = 0,

	reference_angular_frequency_SI = L0 * 3e8 /1.e-6,
    print_every = 10,
)




el = "electron1"
E = 1000. # keV
E /= 511.
vel = math.sqrt(1.-1./(1.+E)**2)
mom = math.sqrt((1.+E)**2-1.)
Species(
	species_type = el,
	position_initialization = "regular",
	momentum_initialization = "maxwell-juettner",
	n_part_per_cell= 100,
	mass = 1.0,
	charge = -1.0,
	nb_density = 1.,
	mean_velocity = [vel, 0., 0.],
	temperature = [0.0000000001]*3,
	time_frozen = 100000000.0,
	bc_part_type_xmin = "none",
	bc_part_type_xmax = "none",
	bc_part_type_ymin = "none",
	bc_part_type_ymax = "none",
	c_part_max = 10.
)

Species(
	species_type = "ion1",
	position_initialization = "regular",
	momentum_initialization = "maxwell-juettner",
	n_part_per_cell= 100,
	mass = 1836.0*27.,
	charge = 0,
	nb_density = 1.,
	mean_velocity = [0., 0., 0.],
	temperature = [0.00000000001]*3,
	time_frozen = 100000000.0,
	bc_part_type_xmin = "none",
	bc_part_type_xmax = "none",
	bc_part_type_ymin = "none",
	bc_part_type_ymax = "none",
	atomic_number = 13)


Collisions(
	species1 = [el],
	species2 = ["ion1"],
	coulomb_log = 0.00000001,
	ionizing = True
)




DiagFields(
	every = 1000000
)


DiagScalar(
	every = 10000000
)




DiagParticleBinning(
	output = "density",
	every = 1,
	species = [el],
	axes = [
		 ["ekin", 0., E, 1000]
	]
)
