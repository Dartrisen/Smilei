#ifndef PROJECTOR3D4ORDERV_H
#define PROJECTOR3D4ORDERV_H

#include "Projector3D.h"


class Projector3D4OrderV : public Projector3D
{
public:
    Projector3D4OrderV( Params &, Patch *patch );
    ~Projector3D4OrderV();
    
    //! Project global current densities (EMfields->Jx_/Jy_/Jz_)
    inline void currents( double *Jx, double *Jy, double *Jz, Particles &particles, unsigned int istart, unsigned int iend, std::vector<double> *invgf, int *iold, double *deltaold, int ipart_ref = 0 );
    //! Project global current densities (EMfields->Jx_/Jy_/Jz_/rho), diagFields timestep
    inline void currentsAndDensity( double *Jx, double *Jy, double *Jz, double *rho, Particles &particles, unsigned int istart, unsigned int iend, std::vector<double> *invgf, int *iold, double *deltaold, int ipart_ref = 0 );
    
    //! Project global current densities (EMfields->Jx_/Jy_/Jz_)
    inline void currentsForTasks( double *Jx, double *Jy, double *Jz, int bin_shift, Particles &particles, unsigned int istart, unsigned int iend, std::vector<double> *invgf, int *iold, double *deltaold, int ipart_ref = 0 );
    //! Project global current densities (EMfields->Jx_/Jy_/Jz_/rho), diagFields timestep
    inline void currentsAndDensityForTasks( double *Jx, double *Jy, double *Jz, double *rho, int bin_shift, Particles &particles, unsigned int istart, unsigned int iend, std::vector<double> *invgf, int *iold, double *deltaold, int ipart_ref = 0 );

    //! Project global current charge (EMfields->rho_), frozen & diagFields timestep
    void basic( double *rhoj, Particles &particles, unsigned int ipart, unsigned int bin, int bin_shift = 0 ) override final;
    
    //! Project global current densities if Ionization in SpeciesV::dynamics,
    void ionizationCurrents( Field *Jx, Field *Jy, Field *Jz, Particles &particles, int ipart, LocalFields Jion ) override final;

    //! Project global current densities if Ionization in SpeciesV::dynamics,
    void ionizationCurrentsForTasks( double *b_Jx, double *b_Jy, double *b_Jz, Particles &particles, int ipart, LocalFields Jion, int bin_shift ) override final;
    
    //!Wrapper
    void currentsAndDensityWrapper( ElectroMagn *EMfields, Particles &particles, SmileiMPI *smpi, int istart, int iend, int ithread, bool diag_flag, bool is_spectral, int ispec, int icell, int ipart_ref ) override final;
    
    //!Wrapper for projection on buffers
    void currentsAndDensityWrapperOnBuffers( double *b_Jx, double *b_Jy, double *b_Jz, double *b_rho, int bin_width, Particles &particles, SmileiMPI *smpi, int istart, int iend, int ithread, bool diag_flag, bool is_spectral, int ispec, int icell, int ipart_ref = 0 ) override final;

    void susceptibility( ElectroMagn *EMfields, Particles &particles, double species_mass, SmileiMPI *smpi, int istart, int iend,  int ithread, int icell, int ipart_ref ) override;
    
private:
    static constexpr double dble_1_ov_384   = 1.0/384.0;
    static constexpr double dble_1_ov_48    = 1.0/48.0;
    static constexpr double dble_1_ov_16    = 1.0/16.0;
    static constexpr double dble_1_ov_12    = 1.0/12.0;
    static constexpr double dble_1_ov_24    = 1.0/24.0;
    static constexpr double dble_19_ov_96   = 19.0/96.0;
    static constexpr double dble_11_ov_24   = 11.0/24.0;
    static constexpr double dble_1_ov_4     = 1.0/4.0;
    static constexpr double dble_1_ov_6     = 1.0/6.0;
    static constexpr double dble_115_ov_192 = 115.0/192.0;
    static constexpr double dble_5_ov_8     = 5.0/8.0;
    
};

#endif

