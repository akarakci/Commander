
COBJS  := d1mach.o drc3jj.o hashtbl.o powell_mod.o comm_hdf_mod.o sharp.o sort_utils.o math_tools.o locate_mod.o spline_1D_mod.o \
          spline_2D_mod.o InvSamp_mod.o comm_system_backend.o comm_system_mod.o comm_map_mod.o \
          comm_defs.o comm_conviqt_mod.o \
	  comm_utils.o comm_huffman_mod.o comm_cr_utils.o comm_cr_precond_mod.o \
          comm_shared_output_mod.o comm_status_mod.o \
	  comm_bp_utils.o comm_param_mod.o comm_comp_mod.o comm_diffuse_comp_mod.o \
	  comm_cmb_comp_mod.o comm_powlaw_comp_mod.o comm_physdust_comp_mod.o comm_MBB_comp_mod.o \
          comm_freefree_comp_mod.o comm_line_comp_mod.o comm_spindust_comp_mod.o comm_spindust2_comp_mod.o \
          comm_md_comp_mod.o comm_template_comp_mod.o comm_ptsrc_comp_mod.o \
	  comm_gain_mod.o comm_nonlin_mod.o comm_N_mod.o comm_N_rms_mod.o \
          comm_B_mod.o comm_B_bl_mod.o comm_beam_mod.o \
          comm_F_int_mod.o comm_F_int_1D_mod.o comm_F_int_0D_mod.o comm_F_int_2D_mod.o \
          comm_fft_mod.o comm_tod_mod.o comm_tod_LFI_mod.o \
          comm_F_line_mod.o comm_data_mod.o comm_bp_mod.o comm_Cl_mod.o \
          comm_chisq_mod.o comm_cr_mod.o comm_signal_mod.o comm_output_mod.o

all : commander hdftest # sharp_test

locate_mod.o :             math_tools.o
spline_1D_mod.o :          locate_mod.o
spline_2D_mod.o :          comm_utils.o
InvSamp_mod.o :            spline_1D_mod.o
comm_map_mod.o :           sharp.o comm_hdf_mod.o comm_param_mod.o
comm_conviqt_mod.o :       sharp.o comm_map_mod.o
comm_hdf_mod.o :           comm_utils.o
comm_fft_mod.o :           locate_mod.o comm_utils.o comm_param_mod.o
comm_tod_mod.o :           comm_utils.o comm_fft_mod.o comm_map_mod.o comm_hdf_mod.o comm_param_mod.o comm_huffman_mod.o
comm_utils.o :             comm_defs.o spline_1D_mod.o
comm_huffman_mod.o :       comm_utils.o
comm_system_mod.o :        comm_system_backend.o
comm_shared_output_mod.o : comm_system_mod.o
comm_status_mod.o :        comm_shared_output_mod.o
comm_utils.o :             sort_utils.o comm_system_mod.o sharp.o
comm_bp_utils.o :          comm_utils.o
comm_param_mod.o :         comm_utils.o comm_status_mod.o hashtbl.o
comm_cr_utils.o :          comm_utils.o
comm_cr_precond_mod.o :    comm_utils.o
comm_comp_mod.o :          comm_bp_mod.o comm_param_mod.o comm_cr_utils.o comm_data_mod.o
comm_Cl_mod.o :            comm_map_mod.o
comm_diffuse_comp_mod.o :  comm_comp_mod.o comm_data_mod.o comm_F_int_mod.o comm_Cl_mod.o \
                           comm_cr_precond_mod.o
comm_template_comp_mod.o : comm_comp_mod.o
comm_ptsrc_comp_mod.o :    comm_template_comp_mod.o comm_F_int_0D_mod.o comm_F_int_2D_mod.o \
                           comm_hdf_mod.o comm_cr_precond_mod.o powell_mod.o
comm_cmb_comp_mod.o :      comm_diffuse_comp_mod.o comm_F_int_0D_mod.o
comm_powlaw_comp_mod.o :   comm_diffuse_comp_mod.o comm_F_int_1D_mod.o
comm_physdust_comp_mod.o : comm_diffuse_comp_mod.o comm_F_int_1D_mod.o
comm_spindust_comp_mod.o : comm_diffuse_comp_mod.o comm_F_int_1D_mod.o
comm_spindust2_comp_mod.o : comm_diffuse_comp_mod.o comm_F_int_1D_mod.o
comm_MBB_comp_mod.o :      comm_diffuse_comp_mod.o comm_F_int_2D_mod.o
comm_freefree_comp_mod.o : comm_diffuse_comp_mod.o comm_F_int_2D_mod.o
comm_line_comp_mod.o :     comm_diffuse_comp_mod.o comm_F_line_mod.o
comm_md_comp_mod.o :       comm_diffuse_comp_mod.o comm_F_line_mod.o
comm_signal_mod.o :        comm_powlaw_comp_mod.o comm_cmb_comp_mod.o \
                           comm_spindust_comp_mod.o comm_spindust2_comp_mod.o comm_MBB_comp_mod.o \
                           comm_freefree_comp_mod.o comm_line_comp_mod.o \
                           comm_md_comp_mod.o comm_template_comp_mod.o \
                           comm_cr_mod.o comm_physdust_comp_mod.o
comm_nonlin_mod.o :        comm_data_mod.o comm_comp_mod.o comm_chisq_mod.o \
                           comm_gain_mod.o comm_output_mod.o
comm_gain_mod.o :          comm_data_mod.o comm_comp_mod.o comm_chisq_mod.o
comm_N_mod.o :             comm_param_mod.o
comm_N_rms_mod.o :         comm_N_mod.o
comm_noise_mod.o :         comm_N_rms_mod.o
comm_bp_mod.o :            comm_bp_utils.o comm_param_mod.o
comm_fg_component_mod.o :  comm_bp_mod.o
comm_F_int_mod.o :         comm_utils.o
comm_F_line_mod.o :        comm_F_int_mod.o 
comm_F_int_0D_mod.o :      comm_F_int_mod.o 
comm_F_int_1D_mod.o :      comm_F_int_mod.o spline_1D_mod.o
comm_F_int_2D_mod.o :      comm_F_int_mod.o spline_2D_mod.o comm_utils.o
comm_B_mod.o :             comm_map_mod.o
comm_B_bl_mod.o :          comm_B_mod.o 
comm_beam_mod.o :          comm_B_bl_mod.o
comm_data_mod.o :          comm_map_mod.o comm_noise_mod.o comm_bp_mod.o comm_beam_mod.o comm_tod_mod.o \
                           comm_tod_LFI_mod.o
comm_cr_mod.o :            comm_data_mod.o comm_comp_mod.o \
                           comm_template_comp_mod.o comm_diffuse_comp_mod.o comm_output_mod.o
comm_chisq_mod.o :         comm_data_mod.o comm_comp_mod.o
comm_output_mod.o :        comm_comp_mod.o comm_hdf_mod.o comm_Cl_mod.o
commander.o :              comm_signal_mod.o comm_data_mod.o comm_cr_mod.o comm_chisq_mod.o \
                           comm_output_mod.o




commander : libcommander.a commander.o
	$(MPF90) -o commander commander.o $(LINK) $(MPFCLIBS)

sharp_test : sharp.o sharp_test.o
	$(MPF90) -o sharp_test sharp_test.o sharp.o $(LINK) $(MPFCLIBS)

hdftest : hdftest.o 
	$(MPF90) -o hdftest hdftest.o $(LINK) $(MPFCLIBS)

libcommander.a : $(COBJS)
	$(AR) $(ARFLAGS) libcommander.a $(COBJS) 
	$(RANLIB) libcommander.a

%.o : %.F90
	$(MPF90) $(F90COMP) -c $<

%.o : %.f90
	$(MPF90) $(F90COMP) -c $<

%.o : %.f
	$(MPF77) $(FCOMP) -c $<

%.o : %.cpp
	$(MPCXX) $(CXXCOMP) -c $< 

%.f90 : %.f90.in
	$(TEMPITA) < "$<" > "$@"

clean :
	@rm -f *.o *.mod *.MOD *.a *~ commander
