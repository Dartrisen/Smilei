
#ifndef ELECTROMAGNBC_FACTORY_H
#define ELECTROMAGNBC_FACTORY_H

#include "ElectroMagnBC.h"
#include "ElectroMagnBC1D_SM.h"
#include "ElectroMagnBC1D_refl.h"
#include "ElectroMagnBC2D_SM.h"
#include "ElectroMagnBC2D_refl.h"
#include "ElectroMagnBC3D_SM.h"
#include "ElectroMagnBCRZ_SM.h"
#include "ElectroMagnBCRZ_Axis.h"
#include "ElectroMagnBCRZ_BM.h"
#include "Params.h"


//  --------------------------------------------------------------------------------------------------------------------
//! Constructor for the ElectroMagnetic Boundary conditions factory
//  --------------------------------------------------------------------------------------------------------------------
class ElectroMagnBC_Factory {
    
public:
    
    static std::vector<ElectroMagnBC*> create(Params& params, Patch* patch) {
        
        std::vector<ElectroMagnBC*> emBoundCond;

        // periodic (=NULL) boundary conditions
        emBoundCond.resize(2*params.nDim_field, NULL);
        MESSAGE(params.geometry);
        // -----------------
        // For 1Dcartesian Geometry
        // -----------------
        if ( params.geometry == "1Dcartesian" ) {
            
            
            // AT X = XMIN,XMAX
            // ----------------
            for (unsigned int ii=0;ii<2;ii++) {
                // silver-muller (injecting/absorbing bcs)
                if ( params.EM_BCs[0][ii] == "silver-muller" ) {
                    emBoundCond[ii] = new ElectroMagnBC1D_SM(params, patch, ii);
                }
                // reflective bcs
                else if ( params.EM_BCs[0][ii] == "reflective" ) {
                    emBoundCond[ii] = new ElectroMagnBC1D_refl(params, patch, ii);
                }
                // else: error
                else if ( params.EM_BCs[0][ii] != "periodic" ) {
                    ERROR( "Unknown EM x-boundary condition `" << params.EM_BCs[0][ii] << "`");
                }
            }
            
        }//1Dcartesian
        
        
        // -----------------
        // For 2Dcartesian Geometry
        // -----------------
        else if ( params.geometry == "2Dcartesian" ) {
            
            for (unsigned int ii=0;ii<2;ii++) {
                // X DIRECTION
                // silver-muller (injecting/absorbing bcs)
                if ( params.EM_BCs[0][ii] == "silver-muller" ) {
                    emBoundCond[ii] = new ElectroMagnBC2D_SM(params, patch, ii);
                }
                // reflective bcs
                else if ( params.EM_BCs[0][ii] == "reflective" ) {
                    emBoundCond[ii] = new ElectroMagnBC2D_refl(params, patch, ii);
                }
                // else: error
                else if ( params.EM_BCs[0][ii] != "periodic" ) {
                    ERROR( "Unknown EM x-boundary condition `" << params.EM_BCs[0][ii] << "`");
                }
                
                // Y DIRECTION
                // silver-muller bcs (injecting/absorbin)
                if ( params.EM_BCs[1][ii] == "silver-muller" ) {
                    emBoundCond[ii+2] = new ElectroMagnBC2D_SM(params, patch, ii+2);
                }
                // reflective bcs
                else if ( params.EM_BCs[1][ii] == "reflective" ) {
                    emBoundCond[ii+2] = new ElectroMagnBC2D_refl(params, patch, ii+2);
                }
                // else: error
                else if ( params.EM_BCs[1][ii] != "periodic" ) {
                    ERROR( "Unknown EM y-boundary condition `" << params.EM_BCs[1][ii] << "`");
                }
            }
            
        }//2Dcartesian
        
        // -----------------
        // For 3Dcartesian Geometry
        // -----------------
        else if ( params.geometry == "3Dcartesian" ) {
            
            for (unsigned int ii=0;ii<2;ii++) {
                // X DIRECTION
                // silver-muller (injecting/absorbing bcs)
                if ( params.EM_BCs[0][ii] == "silver-muller" ) {
                    emBoundCond[ii] = new ElectroMagnBC3D_SM(params, patch, ii);
                }
                // else: error
                else if ( params.EM_BCs[0][ii] != "periodic" ) {
                    ERROR( "Unknown EM x-boundary condition `" << params.EM_BCs[0][ii] << "`");
                }
                
                // Y DIRECTION
                // silver-muller bcs (injecting/absorbin)
                if ( params.EM_BCs[1][ii] == "silver-muller" ) {
                    emBoundCond[ii+2] = new ElectroMagnBC3D_SM(params, patch, ii+2);
                }
                // else: error
                else if ( params.EM_BCs[1][ii] != "periodic" ) {
                    ERROR( "Unknown EM y-boundary condition `" << params.EM_BCs[1][ii] << "`");
                }

                // Z DIRECTION
                // silver-muller bcs (injecting/absorbin)
                if ( params.EM_BCs[2][ii] == "silver-muller" ) {
                    emBoundCond[ii+4] = new ElectroMagnBC3D_SM(params, patch, ii+4);
                }
                // else: error
                else if ( params.EM_BCs[2][ii] != "periodic" ) {
                    ERROR( "Unknown EM z-boundary condition `" << params.EM_BCs[2][ii] << "`");
                }
            }
            
        }//3Dcartesian       

        // -----------------
        // For theta mode Geometry
        // -----------------
        else if ( params.geometry == "3drz" ) {
			
            for (unsigned int ii=0;ii<2;ii++) {

                // X DIRECTION
                // silver-muller (injecting/absorbing bcs)
				MESSAGE(params.EM_BCs[0][ii]);
                if ( params.EM_BCs[0][ii] == "silver-muller" ) {
                    emBoundCond[ii] = new ElectroMagnBCRZ_SM(params, patch, ii);
					
                }
				
                else if ( params.EM_BCs[0][ii] != "periodic" ) {
                    ERROR( "Unknown EM x-boundary condition `" << params.EM_BCs[0][ii] << "`");
                }
            }
                
            // R DIRECTION
            emBoundCond[2] = new ElectroMagnBCRZ_Axis(params, patch, 2);
            // silver-muller bcs (injecting/absorbin)
			MESSAGE("bc AXIS");
            if ( params.EM_BCs[1][1] == "Buneman" ) {
                emBoundCond[3] = new ElectroMagnBCRZ_BM(params, patch, 3);
            }
			
            // else: error
            else  {
                ERROR( "Unknown EM y-boundary condition `" << params.EM_BCs[1][1] << "`");
            }
			MESSAGE( params.EM_BCs[1][1]);
            
        }//3drz       

        // OTHER GEOMETRIES ARE NOT DEFINED ---
        else {
            ERROR( "Unknown geometry : " << params.geometry );
        }
        
        return emBoundCond;
    }
    
};

#endif

