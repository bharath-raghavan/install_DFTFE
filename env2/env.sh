module load cpe/25.03
module load PrgEnv-gnu
module load gcc-native/14.2
module load craype-accel-amd-gfx90a
module load rocm/6.3.1
module load  Core/25.03
module load openblas/0.3.28
module load cmake
module load boost
module unload cray-libsci

export MPICH_GPU_SUPPORT_ENABLED=1

export WD=/lustre/orion/mat295/scratch/dsambit/install_DFTFE_elpa2025
export INST=$WD/env2

export LD_LIBRARY_PATH=$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH

