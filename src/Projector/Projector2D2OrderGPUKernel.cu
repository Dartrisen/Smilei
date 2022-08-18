#if defined( SMILEI_ACCELERATOR_GPU_OMP )

    //! Simple switch to jump between the reference (omp) implementation and the
    //! hip one.
    //! NOTE: If you wanna use the OMP version, you must rename this file to
    //! .cpp instead of .cu for the HIP. The preprocessor and the Smilei
    //! makefile will take care of the rest.
    //!
    #if defined( __HIP__ )
    // HIP compiler support enabled (for .cu files)
    #else
        #define PRIVATE_SMILEI_USE_OPENMP_PROJECTION_IMPLENTATION = 1
    #endif

    #if defined( PRIVATE_SMILEI_USE_OPENMP_PROJECTION_IMPLENTATION )
        #include <cmath>

        #include "Tools.h"
    #else
        #include <hip/hip_runtime.h>

        #include "Params.h"
        #include "gpu.h"
    #endif

    #if defined( PRIVATE_SMILEI_USE_OPENMP_PROJECTION_IMPLENTATION )

namespace naive {

    static inline void
    currentDepositionKernel( double *__restrict__ Jx,
                             double *__restrict__ Jy,
                             double *__restrict__ Jz,
                             int Jx_size,
                             int Jy_size,
                             int Jz_size,
                             const double *__restrict__ device_particle_position_x,
                             const double *__restrict__ device_particle_position_y,
                             const double *__restrict__ device_particle_momentum_z,
                             const short *__restrict__ device_particle_charge,
                             const double *__restrict__ device_particle_weight,
                             const int *__restrict__ host_bin_index,
                             unsigned int x_dimension_bin_count,
                             unsigned int y_dimension_bin_count,
                             const double *__restrict__ invgf_,
                             const int *__restrict__ iold_,
                             const double *__restrict__ deltaold_,
                             double inv_cell_volume,
                             double dx_inv,
                             double dy_inv,
                             double dx_ov_dt,
                             double dy_ov_dt,
                             int    i_domain_begin,
                             int    j_domain_begin,
                             int    nprimy,
                             int    pxr )
    {
        const unsigned int bin_count = x_dimension_bin_count * y_dimension_bin_count;

        SMILEI_ASSERT( bin_count > 0 );

        const int particle_count = host_bin_index[bin_count - 1];

            // // Arrays used for the Esirkepov projection method
            // static constexpr bool kAutoDeviceFree = true;
            // const std::size_t     kTmpArraySize   = particle_count * 5;

            // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> Sx0_buffer{ kTmpArraySize };
            // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> Sx1_buffer{ kTmpArraySize };
            // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> Sy0_buffer{ kTmpArraySize };
            // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> Sy1_buffer{ kTmpArraySize };
            // // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> DSx_buffer{ kTmpArraySize };
            // // smilei::tools::gpu::NonInitializingVector<double, kAutoDeviceFree> DSy_buffer{ kTmpArraySize };

            // double *const __restrict__ Sx0_buffer_data = Sx0_buffer.data();
            // double *const __restrict__ Sx1_buffer_data = Sx1_buffer.data();
            // double *const __restrict__ Sy0_buffer_data = Sy0_buffer.data();
            // double *const __restrict__ Sy1_buffer_data = Sy1_buffer.data();
            // // double *const __restrict__ DSx_buffer_data = DSx_buffer.data();
            // // double *const __restrict__ DSy_buffer_data = DSy_buffer.data();

        #pragma omp target     is_device_ptr /* map */ ( /* to: */                                            \
                                                     device_particle_position_x /* [0:particle_count] */, \
                                                     device_particle_position_y /* [0:particle_count] */, \
                                                     device_particle_momentum_z /* [0:particle_count] */, \
                                                     device_particle_charge /* [0:particle_count] */,     \
                                                     device_particle_weight /* [0:particle_count] */ )
        #pragma omp teams thread_limit( 64 )
        #pragma omp distribute parallel for
        for( int particle_index = 0; particle_index < particle_count; ++particle_index ) {
            const double invgf                        = invgf_[particle_index];
            const int *const __restrict__ iold        = &iold_[particle_index];
            const double *const __restrict__ deltaold = &deltaold_[particle_index];

            double Sx0[5];
            double Sx1[5];
            double Sy0[5];
            double Sy1[5];
            // double DSx[5];
            // double DSy[5];

            // double *const __restrict__ Sx0 = Sx0_buffer_data + 5 * ( particle_index - 0 );
            // double *const __restrict__ Sx1 = Sx1_buffer_data + 5 * ( particle_index - 0 );
            // double *const __restrict__ Sy0 = Sy0_buffer_data + 5 * ( particle_index - 0 );
            // double *const __restrict__ Sy1 = Sy1_buffer_data + 5 * ( particle_index - 0 );
            // // double *const __restrict__ DSx = DSx_buffer_data + 5 * ( particle_index - 0 );
            // // double *const __restrict__ DSy = DSy_buffer_data + 5 * ( particle_index - 0 );

            // Variable declaration & initialization
            // Esirkepov's paper: https://arxiv.org/pdf/physics/9901047.pdf

            // Locate the particle on the primal grid at former time-step & calculate coeff. S0
            {
                const double delta  = deltaold[0 * particle_count];
                const double delta2 = delta * delta;
                Sx0[0]              = 0.0;
                Sx0[1]              = 0.5 * ( delta2 - delta + 0.25 );
                Sx0[2]              = 0.75 - delta2;
                Sx0[3]              = 0.5 * ( delta2 + delta + 0.25 );
                Sx0[4]              = 0.0;
            }
            {
                const double delta  = deltaold[1 * particle_count];
                const double delta2 = delta * delta;
                Sy0[0]              = 0.0;
                Sy0[1]              = 0.5 * ( delta2 - delta + 0.25 );
                Sy0[2]              = 0.75 - delta2;
                Sy0[3]              = 0.5 * ( delta2 + delta + 0.25 );
                Sy0[4]              = 0.0;
            }

            // Locate the particle on the primal grid at current time-step & calculate coeff. S1
            {
                const double xpn      = device_particle_position_x[particle_index] * dx_inv;
                const int    ip       = std::round( xpn );
                const int    ipo      = iold[0 * particle_count];
                const int    ip_m_ipo = ip - ipo - i_domain_begin;
                const double delta    = xpn - static_cast<double>( ip );
                const double delta2   = delta * delta;

                Sx1[0] = 0.0;
                Sx1[1] = 0.0;
                // Sx1[2] = 0.0; // Always set below
                Sx1[3] = 0.0;
                Sx1[4] = 0.0;

                Sx1[ip_m_ipo + 1] = 0.5 * ( delta2 - delta + 0.25 );
                Sx1[ip_m_ipo + 2] = 0.75 - delta2;
                Sx1[ip_m_ipo + 3] = 0.5 * ( delta2 + delta + 0.25 );
            }
            {
                const double ypn      = device_particle_position_y[particle_index] * dy_inv;
                const int    jp       = std::round( ypn );
                const int    jpo      = iold[1 * particle_count];
                const int    jp_m_jpo = jp - jpo - j_domain_begin;
                const double delta    = ypn - static_cast<double>( jp );
                const double delta2   = delta * delta;

                Sy1[0] = 0.0;
                Sy1[1] = 0.0;
                // Sy1[2] = 0.0; // Always set below
                Sy1[3] = 0.0;
                Sy1[4] = 0.0;

                Sy1[jp_m_jpo + 1] = 0.5 * ( delta2 - delta + 0.25 );
                Sy1[jp_m_jpo + 2] = 0.75 - delta2;
                Sy1[jp_m_jpo + 3] = 0.5 * ( delta2 + delta + 0.25 );
            }

            // DSx[0] = Sx1[0] - Sx0[0];
            // DSx[1] = Sx1[1] - Sx0[1];
            // DSx[2] = Sx1[2] - Sx0[2];
            // DSx[3] = Sx1[3] - Sx0[3];
            // DSx[4] = Sx1[4] - Sx0[4];

            // DSy[0] = Sy1[0] - Sy0[0];
            // DSy[1] = Sy1[1] - Sy0[1];
            // DSy[2] = Sy1[2] - Sy0[2];
            // DSy[3] = Sy1[3] - Sy0[3];
            // DSy[4] = Sy1[4] - Sy0[4];
            // }

            // // Charge deposition on the grid

            // for( int particle_index = 0; particle_index < particle_count; ++particle_index ) {
            //     const double invgf                        = invgf_[particle_index];
            //     const int *const __restrict__ iold        = &iold_[particle_index];
            //     const double *const __restrict__ deltaold = &deltaold_[particle_index];

            //     double *const __restrict__ Sx0 = Sx0_buffer_data + 5 * ( particle_index - 0 );
            //     double *const __restrict__ Sx1 = Sx1_buffer_data + 5 * ( particle_index - 0 );
            //     double *const __restrict__ Sy0 = Sy0_buffer_data + 5 * ( particle_index - 0 );
            //     double *const __restrict__ Sy1 = Sy1_buffer_data + 5 * ( particle_index - 0 );
            //     // double *const __restrict__ DSx = DSx_buffer_data + 5 * ( particle_index - 0 );
            //     // double *const __restrict__ DSy = DSy_buffer_data + 5 * ( particle_index - 0 );

            // (x,y,z) components of the current density for the macro-particle
            const double charge_weight = inv_cell_volume * static_cast<double>( device_particle_charge[particle_index] ) * device_particle_weight[particle_index];
            const double crx_p         = charge_weight * dx_ov_dt;
            const double cry_p         = charge_weight * dy_ov_dt;
            const double crz_p         = charge_weight * ( 1.0 / 3.0 ) * device_particle_momentum_z[particle_index] * invgf;

            // This is the particle position as grid index
            // This minus 2 come from the order 2 scheme, based on a 5 points stencil from -2 to +2.
            const int ipo = iold[0 * particle_count] - 2;
            const int jpo = iold[1 * particle_count] - 2;

            for( unsigned int i = 0; i < 1; ++i ) {
                const int iloc = ( i + ipo ) * nprimy + jpo;
                    /* Jx[iloc] += tmpJx[0]; */
        #pragma omp atomic update
                Jz[iloc] += crz_p * ( Sy1[0] * ( /* 0.5 * Sx0[i] + */ Sx1[i] ) );
                double tmp = 0.0;
                for( unsigned int j = 1; j < 5; j++ ) {
                    tmp -= cry_p * ( Sy1[j - 1] - Sy0[j - 1] ) * ( Sx0[i] + 0.5 * ( Sx1[i] - Sx0[i] ) );
        #pragma omp atomic update
                    Jy[iloc + j + pxr * ( /* i + */ ipo )] += tmp;
        #pragma omp atomic update
                    Jz[iloc + j] += crz_p * ( Sy0[j] * ( 0.5 * Sx1[i] /* + Sx0[i] */ ) +
                                              Sy1[j] * ( /* 0.5 * Sx0[i] + */ Sx1[i] ) );
                }
            }

            double tmpJx[5]{};

            for( unsigned int i = 1; i < 5; ++i ) {
                const int iloc = ( i + ipo ) * nprimy + jpo;
                tmpJx[0] -= crx_p * ( Sx1[i - 1] - Sx0[i - 1] ) * ( 0.5 * ( Sy1[0] - Sy0[0] ) );
        #pragma omp atomic update
                Jx[iloc] += tmpJx[0];
        #pragma omp atomic update
                Jz[iloc] += crz_p * ( Sy1[0] * ( 0.5 * Sx0[i] + Sx1[i] ) );
                double tmp = 0.0;
                for( unsigned int j = 1; j < 5; ++j ) {
                    tmpJx[j] -= crx_p * ( Sx1[i - 1] - Sx0[i - 1] ) * ( Sy0[j] + 0.5 * ( Sy1[j] - Sy0[j] ) );
        #pragma omp atomic update
                    Jx[iloc + j] += tmpJx[j];
                    tmp -= cry_p * ( Sy1[j - 1] - Sy0[j - 1] ) * ( Sx0[i] + 0.5 * ( Sx1[i] - Sx0[i] ) );
        #pragma omp atomic update
                    Jy[iloc + j + pxr * ( i + ipo )] += tmp;

        #pragma omp atomic update
                    Jz[iloc + j] += crz_p * ( Sy0[j] * ( 0.5 * Sx1[i] + Sx0[i] ) +
                                              Sy1[j] * ( 0.5 * Sx0[i] + Sx1[i] ) );
                }
            }
        }
    }
} // namespace naive

    #else

namespace hip {
    namespace detail {
        void checkErrors( ::hipError_t an_error_code,
                          const char  *file_name,
                          int          line )
        {
            if( an_error_code != ::hipError_t::hipSuccess ) {
                std::cout << "HIP error at " << file_name << ":" << line
                          << " -> " << ::hipGetErrorString( an_error_code );
                std::exit( EXIT_FAILURE );
            }
        }
    } // namespace detail

        #define checkHIPErrors( an_expression )                           \
            do {                                                          \
                detail::checkErrors( an_expression, __FILE__, __LINE__ ); \
            } while( 0 )

    namespace kernel {

        template <typename T>
        __device__ void
        atomicAdd( T *a_pointer, T a_value )
        {
            ::atomicAdd( a_pointer, a_value ); // Atomic     | the kernel is correct
            *a_pointer = a_value;              // Not atomic | the kernel is wrong but 10x faster
        }

        template <typename Float>
        __global__ void
        // __launch_bounds__(128, 4)
        depositeForAllCurrentDimensions( double *__restrict__ device_Jx,
                                         double *__restrict__ device_Jy,
                                         double *__restrict__ device_Jz,
                                         int Jx_size,
                                         int Jy_size,
                                         int Jz_size,
                                         const double *__restrict__ device_particle_position_x,
                                         const double *__restrict__ device_particle_position_y,
                                         const double *__restrict__ device_particle_momentum_z,
                                         const short *__restrict__ device_particle_charge,
                                         const double *__restrict__ device_particle_weight,
                                         const int *__restrict__ device_bin_index,
                                         const double *__restrict__ device_invgf_,
                                         const int *__restrict__ device_iold_,
                                         const double *__restrict__ device_deltaold_,
                                         Float inv_cell_volume,
                                         Float dx_inv,
                                         Float dy_inv,
                                         Float dx_ov_dt,
                                         Float dy_ov_dt,
                                         int   i_domain_begin,
                                         int   j_domain_begin,
                                         int   nprimy,
                                         int   pxr )
        {
            // TODO(Etienne M): refactor this function. Break it into smaller
            // pieces (lds init/store, coeff computation, deposition etc..)
            // TODO(Etienne M): prefer unsigned int vs int. At least the reader
            // knows the value wont be negative.
            const unsigned int workgroup_size = blockDim.x;
            const unsigned int bin_count      = gridDim.x * gridDim.y;
            const unsigned int loop_stride    = workgroup_size; // This stride should enable better memory access coalescing

            const unsigned int x_cluster_coordinate          = blockIdx.x;
            const unsigned int y_cluster_coordinate          = blockIdx.y;
            const unsigned int workgroup_dedicated_bin_index = x_cluster_coordinate * gridDim.y + y_cluster_coordinate; // The indexing order is: x * ywidth * zwidth + y * zwidth + z
            const unsigned int thread_index_offset           = threadIdx.x;

            // The unit is the cell
            const unsigned int global_x_scratch_space_coordinate_offset = x_cluster_coordinate * Params::getGPUClusterWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ );
            const unsigned int global_y_scratch_space_coordinate_offset = y_cluster_coordinate * Params::getGPUClusterWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ );

            // NOTE: We gain from the particles not being sorted inside a
            // cluster because it reduces the bank conflicts one gets when
            // multiple threads access the same part of the shared memory. Such
            // "conflicted" accesses are serialized !
            // NOTE: We use a bit to much LDS. For Jx, the first row could be
            // discarded, for Jy we could remove the first column.

            static constexpr unsigned int kFieldScratchSpaceSize = Params::getGPUInterpolationClusterCellVolume( 2 /* 2D */, 2 /* 2nd order interpolation */ );

            // NOTE: I tried having only one cache and reusing it. Doing that
            // requires you to iterate multiple time over the particle which is
            // possible but cost more bandwidth. The speedup was ~x0.92.
            __shared__ Float Jx_scratch_space[kFieldScratchSpaceSize];
            __shared__ Float Jy_scratch_space[kFieldScratchSpaceSize];
            __shared__ Float Jz_scratch_space[kFieldScratchSpaceSize];

            // Init the shared memory

            for( unsigned int field_index = thread_index_offset;
                 field_index < kFieldScratchSpaceSize;
                 field_index += workgroup_size ) {
                Jx_scratch_space[field_index] = 0.0;
                Jy_scratch_space[field_index] = 0.0;
                Jz_scratch_space[field_index] = 0.0;
            }

            __syncthreads();

            const unsigned int particle_count = device_bin_index[bin_count - 1];

            // This workgroup has to process distance(last_particle,
            // first_particle) particles
            const unsigned int first_particle = workgroup_dedicated_bin_index == 0 ? 0 :
                                                                                     device_bin_index[workgroup_dedicated_bin_index - 1];
            const unsigned int last_particle  = device_bin_index[workgroup_dedicated_bin_index];

            for( unsigned int particle_index = first_particle + thread_index_offset;
                 particle_index < last_particle;
                 particle_index += loop_stride ) {
                const Float invgf                         = static_cast<Float>( device_invgf_[particle_index] );
                const int *const __restrict__ iold        = &device_iold_[particle_index];
                const double *const __restrict__ deltaold = &device_deltaold_[particle_index];

                Float Sx0[5];
                Float Sx1[5];
                Float Sy0[5];
                Float Sy1[5];
                // double DSx[5];
                // double DSy[5];

                // Variable declaration & initialization
                // Esirkepov's paper: https://arxiv.org/pdf/physics/9901047.pdf

                // Locate the particle on the primal grid at former time-step & calculate coeff. S0
                {
                    const Float delta  = deltaold[0 * particle_count];
                    const Float delta2 = delta * delta;
                    Sx0[0]             = static_cast<Float>( 0.0 );
                    Sx0[1]             = static_cast<Float>( 0.5 ) * ( delta2 - delta + static_cast<Float>( 0.25 ) );
                    Sx0[2]             = static_cast<Float>( 0.75 ) - delta2;
                    Sx0[3]             = static_cast<Float>( 0.5 ) * ( delta2 + delta + static_cast<Float>( 0.25 ) );
                    Sx0[4]             = static_cast<Float>( 0.0 );
                }
                {
                    const Float delta  = deltaold[1 * particle_count];
                    const Float delta2 = delta * delta;
                    Sy0[0]             = static_cast<Float>( 0.0 );
                    Sy0[1]             = static_cast<Float>( 0.5 ) * ( delta2 - delta + static_cast<Float>( 0.25 ) );
                    Sy0[2]             = static_cast<Float>( 0.75 ) - delta2;
                    Sy0[3]             = static_cast<Float>( 0.5 ) * ( delta2 + delta + static_cast<Float>( 0.25 ) );
                    Sy0[4]             = static_cast<Float>( 0.0 );
                }

                // Locate the particle on the primal grid at current time-step & calculate coeff. S1
                {
                    const Float xpn = static_cast<Float>( device_particle_position_x[particle_index] ) * dx_inv;
                    const int   ip  = std::round( xpn );
                    // const int    ip       = static_cast<int>( xpn + 0.5 ); // std::round | rounding approximation which is correct enough and faster in this case
                    const int   ipo      = iold[0 * particle_count];
                    const int   ip_m_ipo = ip - ipo - i_domain_begin;
                    const Float delta    = xpn - static_cast<Float>( ip );
                    const Float delta2   = delta * delta;

                    Sx1[0] = static_cast<Float>( 0.0 );
                    Sx1[1] = static_cast<Float>( 0.0 );
                    // Sx1[2] = 0.0; // Always set below
                    Sx1[3] = static_cast<Float>( 0.0 );
                    Sx1[4] = static_cast<Float>( 0.0 );

                    Sx1[ip_m_ipo + 1] = static_cast<Float>( 0.5 ) * ( delta2 - delta + static_cast<Float>( 0.25 ) );
                    Sx1[ip_m_ipo + 2] = static_cast<Float>( 0.75 ) - delta2;
                    Sx1[ip_m_ipo + 3] = static_cast<Float>( 0.5 ) * ( delta2 + delta + static_cast<Float>( 0.25 ) );
                }
                {
                    const Float ypn = static_cast<Float>( device_particle_position_y[particle_index] ) * dy_inv;
                    const int   jp  = std::round( ypn );
                    // const int    jp       = static_cast<int>( ypn + 0.5 ); // std::round | rounding approximation which is correct enough and faster in this case
                    const int   jpo      = iold[1 * particle_count];
                    const int   jp_m_jpo = jp - jpo - j_domain_begin;
                    const Float delta    = ypn - static_cast<Float>( jp );
                    const Float delta2   = delta * delta;

                    Sy1[0] = static_cast<Float>( 0.0 );
                    Sy1[1] = static_cast<Float>( 0.0 );
                    // Sy1[2] = 0.0; // Always set below
                    Sy1[3] = static_cast<Float>( 0.0 );
                    Sy1[4] = static_cast<Float>( 0.0 );

                    Sy1[jp_m_jpo + 1] = static_cast<Float>( 0.5 ) * ( delta2 - delta + static_cast<Float>( 0.25 ) );
                    Sy1[jp_m_jpo + 2] = static_cast<Float>( 0.75 ) - delta2;
                    Sy1[jp_m_jpo + 3] = static_cast<Float>( 0.5 ) * ( delta2 + delta + static_cast<Float>( 0.25 ) );
                }

                // DSx[0] = Sx1[0] - Sx0[0];
                // DSx[1] = Sx1[1] - Sx0[1];
                // DSx[2] = Sx1[2] - Sx0[2];
                // DSx[3] = Sx1[3] - Sx0[3];
                // DSx[4] = Sx1[4] - Sx0[4];

                // DSy[0] = Sy1[0] - Sy0[0];
                // DSy[1] = Sy1[1] - Sy0[1];
                // DSy[2] = Sy1[2] - Sy0[2];
                // DSy[3] = Sy1[3] - Sy0[3];
                // DSy[4] = Sy1[4] - Sy0[4];

                // (x,y,z) components of the current density for the macro-particle
                const Float charge_weight = inv_cell_volume * static_cast<Float>( device_particle_charge[particle_index] ) * static_cast<Float>( device_particle_weight[particle_index] );
                const Float crx_p         = charge_weight * dx_ov_dt;
                const Float cry_p         = charge_weight * dy_ov_dt;
                const Float crz_p         = charge_weight * static_cast<Float>( 1.0 / 3.0 ) * static_cast<Float>( device_particle_momentum_z[particle_index] ) * invgf;

                // This is the particle position as grid index
                // This minus 2 come from the order 2 scheme, based on a 5 points stencil from -2 to +2.
                const int ipo = iold[0 * particle_count] -
                                2 /* Offset so we dont uses negative numbers in the loop */ -
                                global_x_scratch_space_coordinate_offset /* Offset to get cluster relative coordinates */;
                const int jpo = iold[1 * particle_count] -
                                2 /* Offset so we dont uses negative numbers in the loop */ -
                                global_y_scratch_space_coordinate_offset /* Offset to get cluster relative coordinates */;

                // // Atomic optimized loops
                // // Jx

                // for( unsigned int i = 1; i < 5; ++i ) {
                //     const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                //     for( unsigned int j = 0; j < 5; ++j ) {
                //         tmpJx[j] -= crx_p * ( Sx1[i - 1] - Sx0[i - 1] ) * ( Sy0[j] + static_cast<Float>( 0.5 ) * ( Sy1[j] - Sy0[j] ) );
                //         ::atomicAdd( &Jx_scratch_space[iloc + j], tmpJx[j] );
                //     }
                // }

                // // Jy

                // for( unsigned int i = 0; i < 5; ++i ) {
                //     const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                //     Float     tmp{};
                //     for( unsigned int j = 1; j < 5; ++j ) {
                //         tmp -= cry_p * ( Sy1[j - 1] - Sy0[j - 1] ) * ( Sx0[i] + static_cast<Float>( 0.5 ) * ( Sx1[i] - Sx0[i] ) );
                //         ::atomicAdd( &Jy_scratch_space[iloc + j], tmp );
                //     }
                // }

                // // Jz

                // for( unsigned int i = 0; i < 5; ++i ) {
                //     const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                //     for( unsigned int j = 0; j < 5; ++j ) {
                //         ::atomicAdd( &Jz_scratch_space[iloc + j], crz_p * ( Sy0[j] * ( static_cast<Float>( 0.5 ) * Sx1[i] + Sx0[i] ) +
                //                                                             Sy1[j] * ( static_cast<Float>( 0.5 ) * Sx0[i] + Sx1[i] ) ) );
                //     }
                // }

                // Atomic optimized loops
                // Jx

                Float tmpJx[5]{};

                for( unsigned int i = 1; i < 5; ++i ) {
                    const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                    tmpJx[0] -= crx_p * ( Sx1[i - 1] - Sx0[i - 1] ) * ( static_cast<Float>( 0.5 ) * ( Sy1[0] - Sy0[0] ) );
                    atomicAdd( &Jx_scratch_space[iloc], tmpJx[0] );
                    for( unsigned int j = 1; j < 5; ++j ) {
                        tmpJx[j] -= crx_p * ( Sx1[i - 1] - Sx0[i - 1] ) * ( Sy0[j] + static_cast<Float>( 0.5 ) * ( Sy1[j] - Sy0[j] ) );
                        atomicAdd( &Jx_scratch_space[iloc + j], tmpJx[j] );
                    }
                }

                // Jy

                for( unsigned int i = 0; i < 1; ++i ) {
                    const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                    Float     tmp{};
                    for( unsigned int j = 1; j < 5; j++ ) {
                        tmp -= cry_p * ( Sy1[j - 1] - Sy0[j - 1] ) * ( Sx0[i] + static_cast<Float>( 0.5 ) * ( Sx1[i] - Sx0[i] ) );
                        atomicAdd( &Jy_scratch_space[iloc + j], tmp );
                    }
                }

                for( unsigned int i = 1; i < 5; ++i ) {
                    const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                    Float     tmp{};
                    for( unsigned int j = 1; j < 5; ++j ) {
                        tmp -= cry_p * ( Sy1[j - 1] - Sy0[j - 1] ) * ( Sx0[i] + static_cast<Float>( 0.5 ) * ( Sx1[i] - Sx0[i] ) );
                        atomicAdd( &Jy_scratch_space[iloc + j], tmp );
                    }
                }

                // Jz

                for( unsigned int i = 0; i < 1; ++i ) {
                    const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                    atomicAdd( &Jz_scratch_space[iloc], crz_p * ( Sy1[0] * ( /* 0.5 * Sx0[i] + */ Sx1[i] ) ) );
                    for( unsigned int j = 1; j < 5; j++ ) {
                        atomicAdd( &Jz_scratch_space[iloc + j], crz_p * ( Sy0[j] * ( static_cast<Float>( 0.5 ) * Sx1[i] /* + Sx0[i] */ ) +
                                                                          Sy1[j] * ( /* 0.5 * Sx0[i] + */ Sx1[i] ) ) );
                    }
                }

                for( unsigned int i = 1; i < 5; ++i ) {
                    const int iloc = ( i + ipo ) * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + jpo;
                    atomicAdd( &Jz_scratch_space[iloc], crz_p * ( Sy1[0] * ( static_cast<Float>( 0.5 ) * Sx0[i] + Sx1[i] ) ) );
                    for( unsigned int j = 1; j < 5; ++j ) {
                        atomicAdd( &Jz_scratch_space[iloc + j], crz_p * ( Sy0[j] * ( static_cast<Float>( 0.5 ) * Sx1[i] + Sx0[i] ) +
                                                                          Sy1[j] * ( static_cast<Float>( 0.5 ) * Sx0[i] + Sx1[i] ) ) );
                    }
                }
            }

            __syncthreads();

            for( unsigned int field_index = thread_index_offset;
                 field_index < kFieldScratchSpaceSize;
                 field_index += workgroup_size ) {

                // The indexing order is: x * ywidth * zwidth + y * zwidth + z
                const unsigned int local_x_scratch_space_coordinate = field_index / Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ );
                const unsigned int local_y_scratch_space_coordinate = field_index % Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ );

                const unsigned int global_x_scratch_space_coordinate = global_x_scratch_space_coordinate_offset + local_x_scratch_space_coordinate;
                const unsigned int global_y_scratch_space_coordinate = global_y_scratch_space_coordinate_offset + local_y_scratch_space_coordinate;

                // The indexing order is: x * ywidth * zwidth + y * zwidth + z
                const unsigned int global_memory_index = global_x_scratch_space_coordinate * nprimy + global_y_scratch_space_coordinate;
                const unsigned int scratch_space_index = field_index; // local_x_scratch_space_coordinate * Params::getGPUClusterWithGhostCellWidth( 2 /* 2D */, 2 /* 2nd order interpolation */ ) + local_y_scratch_space_coordinate;

                // These atomics are basically free (very few of them).
                ::atomicAdd( &device_Jx[global_memory_index], static_cast<double>( Jx_scratch_space[scratch_space_index] ) );
                ::atomicAdd( &device_Jy[global_memory_index + /* We handle the FTDT/picsar */ pxr * global_x_scratch_space_coordinate], static_cast<double>( Jy_scratch_space[scratch_space_index] ) );
                ::atomicAdd( &device_Jz[global_memory_index], static_cast<double>( Jz_scratch_space[scratch_space_index] ) );
            }
        }
    } // namespace kernel

    static inline void
    currentDepositionKernel( double *__restrict__ host_Jx,
                             double *__restrict__ host_Jy,
                             double *__restrict__ host_Jz,
                             int Jx_size,
                             int Jy_size,
                             int Jz_size,
                             const double *__restrict__ device_particle_position_x,
                             const double *__restrict__ device_particle_position_y,
                             const double *__restrict__ device_particle_momentum_z,
                             const short *__restrict__ device_particle_charge,
                             const double *__restrict__ device_particle_weight,
                             const int *__restrict__ host_bin_index,
                             unsigned int x_dimension_bin_count,
                             unsigned int y_dimension_bin_count,
                             const double *__restrict__ host_invgf_,
                             const int *__restrict__ host_iold_,
                             const double *__restrict__ host_deltaold_,
                             double inv_cell_volume,
                             double dx_inv,
                             double dy_inv,
                             double dx_ov_dt,
                             double dy_ov_dt,
                             int    i_domain_begin,
                             int    j_domain_begin,
                             int    nprimy,
                             int    pxr )
    {
        int device_count;
        checkHIPErrors( ::hipGetDeviceCount( &device_count ) );
        SMILEI_ASSERT( device_count == 1 );

        // NOTE:
        // This cluster is very strongly bound by atomic operations in LDS (shared memory)
        // TODO(Etienne M): Find a way to lessen the atomic usage

        const ::dim3 kGridDimensionInBlock{ static_cast<uint32_t>( x_dimension_bin_count ), static_cast<uint32_t>( y_dimension_bin_count ), 1 };
        // On an MI100:
        // 448 for F32 and 4x4 cluster width | past 128, the block size does not matter, we are atomic bound anyway
        // 128 for F64 and 4x4 cluster width | atomic bound
        const ::dim3 kBlockDimensionInWorkItem{ 128, 1, 1 };

        using Float = double; // float/double

        auto KernelFunction = kernel::depositeForAllCurrentDimensions<Float>;

        hipLaunchKernelGGL( KernelFunction,
                            kGridDimensionInBlock,
                            kBlockDimensionInWorkItem,
                            0, // Shared memory
                            0, // Stream
                            // Kernel arguments
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_Jx ),
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_Jy ),
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_Jz ),
                            Jx_size, Jy_size, Jz_size,
                            device_particle_position_x,
                            device_particle_position_y,
                            device_particle_momentum_z,
                            device_particle_charge,
                            device_particle_weight,
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_bin_index ),
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_invgf_ ),
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_iold_ ),
                            smilei::tools::gpu::HostDeviceMemoryManagment::GetDevicePointer( host_deltaold_ ),
                            inv_cell_volume,
                            dx_inv, dy_inv,
                            dx_ov_dt, dy_ov_dt,
                            i_domain_begin, j_domain_begin,
                            nprimy,
                            pxr );

        checkHIPErrors( ::hipDeviceSynchronize() );
    }

} // namespace hip

    #endif

//! Project global current densities (EMfields->Jx_/Jy_/Jz_)
//!
extern "C" void
currentDepositionKernel( double *__restrict__ host_Jx,
                         double *__restrict__ host_Jy,
                         double *__restrict__ host_Jz,
                         int Jx_size,
                         int Jy_size,
                         int Jz_size,
                         const double *__restrict__ device_particle_position_x,
                         const double *__restrict__ device_particle_position_y,
                         const double *__restrict__ device_particle_momentum_z,
                         const short *__restrict__ device_particle_charge,
                         const double *__restrict__ device_particle_weight,
                         const int *__restrict__ host_bin_index,
                         unsigned int x_dimension_bin_count,
                         unsigned int y_dimension_bin_count,
                         const double *__restrict__ host_invgf_,
                         const int *__restrict__ host_iold_,
                         const double *__restrict__ host_deltaold_,
                         double inv_cell_volume,
                         double dx_inv,
                         double dy_inv,
                         double dx_ov_dt,
                         double dy_ov_dt,
                         int    i_domain_begin,
                         int    j_domain_begin,
                         int    nprimy,
                         int    pxr )
{
    #if defined( PRIVATE_SMILEI_USE_OPENMP_PROJECTION_IMPLENTATION )
    naive:: // the naive, OMP version serves as a referance along with the CPU version
    #else
    hip::
    #endif
        currentDepositionKernel( host_Jx, host_Jy, host_Jz,
                                 Jx_size, Jy_size, Jz_size,
                                 device_particle_position_x, device_particle_position_y,
                                 device_particle_momentum_z,
                                 device_particle_charge,
                                 device_particle_weight,
                                 host_bin_index,
                                 x_dimension_bin_count,
                                 y_dimension_bin_count,
                                 host_invgf_,
                                 host_iold_, host_deltaold_,
                                 inv_cell_volume,
                                 dx_inv, dy_inv,
                                 dx_ov_dt, dy_ov_dt,
                                 i_domain_begin, j_domain_begin,
                                 nprimy,
                                 pxr );
}

#endif
