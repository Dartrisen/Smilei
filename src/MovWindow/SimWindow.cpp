
#include "SimWindow.h"
#include "PicParams.h"
#include "Species.h"
#include "ElectroMagn.h"
#include "Interpolator.h"
#include "Projector.h"
#include "SmileiMPI.h"
using namespace std;

SimWindow::SimWindow(PicParams& params)
{
    nspace_win_x_ = params.nspace_win_x;
    cell_length_x_   = params.cell_length[0];
    x_moved = 0.;      //The window has not moved at t=0. Warning: not true anymore for restarts.
    vx_win_ = params.vx_win; 
    t_move_win_ = params.t_move_win;      
}

SimWindow::~SimWindow()
{
}

void SimWindow::operate(vector<Species*> vecSpecies, ElectroMagn* EMfields, Interpolator* Interp, Projector* Proj, SmileiMPI* smpi, PicParams& params)
{

    unsigned int clrw;

    if (vecSpecies.size() > 0) {
        clrw = vecSpecies[0]->clrw; //clrw must be the same for all species
    } else {
        clrw = params.clrw; //This is not correct, just an ugly patch. clrw should take the correct global value even when there are no particles.
    }

    smpi->getCellStartingGlobalIndex(0)+= clrw;
    smpi->getDomainLocalMin(0)+= cell_length_x_*clrw;
    smpi->getDomainLocalMax(0)+= cell_length_x_*clrw;

    if (vecSpecies.size() > 0) {
        for (unsigned int ispec=0 ; ispec<vecSpecies.size(); ispec++) {
            vecSpecies[ispec]->movingWindow_x(clrw,smpi,params);
        }
        Interp->mv_win(clrw);
        Proj->mv_win(clrw);
    }
    EMfields->movingWindow_x(clrw, smpi);
    x_moved += cell_length_x_*clrw;


}

/* For discussion
void SimWindow::operate(vector<Patches*> vecPatches, SmileiMPI* smpi, PicParams& params)
{
    int xcall, ycall;
    #pragma omp for
    for (unsigned int ipatch = 0 ; ipatch < vecPatches.size() ; ipatch++) {
        //Si je ne possede pas mon voisin de gauche...
        if (MpiLNeighbour != MPI_PROC_NULL) {
            //...je l'envois...
            Mpi_Send_Patch(MpiLNeighbour);
            //... et je detruit mes donnees.
            delete (vecPatches[ipatch].vecSpecies);
            delete (vecPatches[ipatch].EMfields);
            delete (vecPatches[ipatch].Interp);
            delete (vecPatches[ipatch].Proj);
        //Sinon, je deviens mon voisin de gauche.
        } else {
            Pcoordinates[0] -= 1;
            min_local -= patch_size[0]*dx;
            max_local -= patch_size[0]*dx;
            cell_starting_globalindex[0] -= patch_size[0];
            nbNeighbors ???
            neighbor_[0][1] = hindex;
            corner_neighbor[1][1] = neighbor[1][1];
            corner_neighbor[1][0] = neighbor[1][0];
            hindex = neighbor_[0][0];
            neighbor_[1][0] = corner_neighbor_[0][0] ;
            neighbor_[1][1] = corner_neighbor_[0][1] ;
	    if (Pcoordinates[0]>0){
	        neighbor_[0][0] = generalhilbertindex( m0, m1, Pcoordinates[0]-1, Pcoordinates[1]);
	    } else if (params.bc_em_type_long=="periodic") {
	        neighbor_[0][0] = generalhilbertindex( m0, m1,(1<<m0)-1, Pcoordinates[1]);
            }else {
                neighbor_[0][0] = MPI_PROC_NULL ;
            }
            xcall = Pcoordinates[0]-1;
            ycall = Pcoordinates[1]-1;
            if (params.bc_em_type_long=="periodic") xcall = xcall%((1<<m0)-1);
            if (params.bc_em_type_trans=="periodic") ycall = ycall%((1<<m1)-1);
	    corner_neighbor_[0][0] = generalhilbertindex( m0, m1, xcall, ycall);

                        ycall = Pcoordinates[1]+1;
            if (params.bc_em_type_trans=="periodic") ycall = ycall%((1<<m1)-1);
	    corner_neighbor_[0][1] = generalhilbertindex( m0, m1, xcall, ycall);
             
        }
        //Si je ne possede pas mon voisin de droite...
        if (MpiRNeighbour != MPI_PROC_NULL) {
            //...je reçois.
            Mpi_Receive_Patch(MpiRNeighbour);
            //Les fonctions SendPatch ou ReceivePatch doivent transformer le Patch comme ci dessus.
            //Ce serait plus simple de mettre hindex, neighbor_ et corner_neighbor_ dans un seul et meme tableau.
        }
    }

}

*/



bool SimWindow::isMoving(double time_dual)
{
    return ( (nspace_win_x_) && ((time_dual - t_move_win_)*vx_win_ > x_moved) );
}

void SimWindow::setOperators(vector<Species*> vecSpecies, Interpolator* Interp, Projector* Proj, SmileiMPI* smpi)
{
    smpi->updateMvWinLimits( x_moved, round(x_moved/cell_length_x_) );

    for (unsigned int ispec=0 ; ispec<vecSpecies.size(); ispec++) {
	vecSpecies[ispec]->updateMvWinLimits(x_moved);
    }

    Interp->setMvWinLimits( smpi->getCellStartingGlobalIndex(0) );
    Proj->setMvWinLimits  ( smpi->getCellStartingGlobalIndex(0) );

}
