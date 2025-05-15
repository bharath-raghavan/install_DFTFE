# Installation notes for DFT-FE and its dependencies

. ./env2/env.sh

# All compiled with gcc 14.2!

# different commit for spglib (for v2.1-rc1)
# took scalapack from github (not tar)
# compile elpa with openmp support (see mimic compile)

# Install alglib, libxc, spglib and p4est using the typical route (cf. manual)
function install_alglib {
  cd $WD/src
  if [ ! -d alglib-cpp ]; then 
    wget https://www.alglib.net/translator/re/alglib-4.04.0.cpp.gpl.tgz
    tar xzf alglib-4.04.0.cpp.gpl.tgz
    rm -f alglib-4.04.0.cpp.gpl.tgz
  fi
  cd alglib-cpp/src
  CC -o libAlglib.so -shared -fPIC -O2 *.cpp

  mkdir -p $INST/lib/alglib
  mv libAlglib.so $INST/lib/alglib/
  cp *.h $INST/lib/alglib/

  cd $WD
}

function install_libxc {
  cd $WD/src
  if [ ! -d libxc-7.0.0 ]; then 
    wget https://gitlab.com/libxc/libxc/-/archive/7.0.0/libxc-7.0.0.tar.gz
    tar xzf libxc-7.0.0.tar.gz
    rm libxc-7.0.0.tar.gz
  fi
  cd libxc-7.0.0
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_C_COMPILER=cc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=CC -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF ..
  make -j16
  make install
  cd $WD
}


function install_dftd4 {
  cd $WD/src
  if [ ! -d dftd4-3.7.0 ]; then
    wget https://github.com/dftd4/dftd4/archive/refs/tags/v3.7.0.tar.gz
    tar xzf v3.7.0.tar.gz
    rm v3.7.0.tar.gz
  fi
  cd dftd4-3.7.0
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_Fortran_COMPILER=ftn -DCMAKE_C_COMPILER=cc -DBLAS_LIBRARIES=$OLCF_OPENBLAS_ROOT/lib/libopenblas.so -DLAPACK_LIBRARIES=$OLCF_OPENBLAS_ROOT/lib/libopenblas.so -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$INST -DWITH_OpenMP=OFF ..
  make -j16
  make install
  cd $WD
}

function install_spglib {
  cd $WD/src
  if [ ! -d spglib ]; then
    git clone https://github.com/atztogo/spglib.git
    cd spglib && git checkout e78c3de # v2.1.0-rc1
  fi
  cd spglib
  rm -fr build
  mkdir -p build && cd build
  cmake -DCMAKE_CXX_COMPILER=CC -DCMAKE_C_COMPILER=cc -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}

function install_p4est {
  cd $WD/src
  rm -rf p4est
  mkdir p4est
  cd p4est
  wget https://p4est.github.io/release/p4est-2.8.7.tar.gz
  wget https://raw.githubusercontent.com/dftfeDevelopers/dftfe/manual/p4est-setup-craycompiler.sh
  chmod u+x p4est-setup-craycompiler.sh
  ./p4est-setup-craycompiler.sh p4est-2.8.7.tar.gz $INST
  cd $WD
 }


# Install netlib-scalapack 2.2.2 version linking to openblas
# note that the openblas (sourced via module) provides lapack
function install_scalapack {
  cd $WD/src
  if [ ! -d scalapack-2.2.2 ]; then
    wget https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v2.2.2.tar.gz
    tar xzf v2.2.2.tar.gz
    rm -f v2.2.2.tar.gz
  fi
  cd scalapack-2.2.2
  
  mkdir build && cd build
  cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=cc -DCMAKE_Fortran_COMPILER=ftn -DCMAKE_C_FLAGS="-fPIC -march=znver3 -Wno-error=implicit-function-declaration" -DCMAKE_Fortran_FLAGS="-fPIC -march=znver3 -fallow-argument-mismatch" -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}

# Install RCCL (https://github.com/ROCmSoftwarePlatform/rccl)
#    cmake -DCMAKE_CXX_COMPILER=${ROCM_PATH}/bin/hipcc -DCMAKE_CXX_FLAGS="-I${MPICH_DIR}/include -I${ROCM_PATH}/include" -DCMAKE_SHARED_LINKER_FLAGS="-L${ROCM_PATH}/lib -lamdhip64 -L${MPICH_DIR}/lib -lmpi -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_hsa" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$ROCM_PATH;${MPICH_DIR}" ../

# Install RCCL OFI plugin
function install_ofi_rccl {
  cd $WD/src
  if [ ! -d aws-ofi-rccl ]; then 
    git clone https://github.com/ROCmSoftwarePlatform/aws-ofi-rccl
    cd aws-ofi-rccl
    module load libtool
    bash ./autogen.sh
  fi
  cd aws-ofi-rccl
  rm -fr build
  mkdir build && cd build

  CC=cc ../configure --with-libfabric=/opt/cray/libfabric/1.15.2.0 --with-hip=$CRAY_ROCM_PREFIX --with-rccl=$CRAY_ROCM_PREFIX --with-mpi=$MPICH_DIR --prefix=$INST --build=amd64-linux-gnu --target=amd64-linux-gnu --host=amd64-linux-gnu
  make -j8
  make install
  cd $WD
}

# Install ELPA latest version (elpa-2025.01.001) with AMD GPU support
function install_elpa {
    cd $WD/src
    if [ ! -d elpa ]; then
        ver=2025.01.001
        wget https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/$ver/elpa-$ver.tar.gz
        tar xzf elpa-$ver.tar.gz
        mv elpa-$ver elpa
        rm -f elpa-$ver.tar.gz
        cd elpa
        cd ..
    fi
    cd elpa

export SCALAPACK_ROOT=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/scalapack/v2.2.2/install
/lustre/orion/stf006/proj-shared/raghavan/code/lib/elpa/v2025.01.001/configure CXX=hipcc CC=hipcc FC=ftn CFLAGS="-march=znver3 -fPIC -O2 $CRAY_ROCM_INCLUDE_OPTS -I$ROCM_PATH/include/rocsolver\
 --amdgpu-target=gfx90a -I$MPICH_DIR/include" FCFLAGS="-march=znver3 -O2 -fPIC" CXXFLAGS="-std=c++17 -march=znver3 -fPIC -O2\
  $CRAY_ROCM_INCLUDE_OPTS -I$ROCM_PATH/include/rocsolver --amdgpu-target=gfx90a -I$MPICH_DIR/include" LIBS="-L$ROCM_PATH/lib\
   -lamdhip64 -lrocblas -lrocsolver -L$MPICH_DIR/lib -lmpi $CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a\
    $PE_MPICH_GTL_LIBS_amd_gfx90a -L$SCALAPACK_ROOT/lib -lscalapack -L$OLCF_OPENBLAS_ROOT/lib -lopenblas " --enable-amd-gpu --prefix=$ELPA_INST\
     --disable-avx512 --enable-c-tests=no --enable-option-checking=fatal --enable-shared --enable-cpp-tests=no --enable-hipcub --enable-openmp # with openmp support
make -j16
make install

function install_kokkos {
  cd $WD/src
  if [ ! -d kokkos-4.6.00 ]; then 
    wget https://github.com/kokkos/kokkos/archive/refs/tags/4.6.00.tar.gz
    tar xzvf 4.6.00.tar.gz
    rm 4.6.00.tar.gz
  fi
  cd kokkos-4.6.00
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_C_COMPILER=cc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=CC -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}


# Install latest release dealii from https://github.com/dealii/dealii

ver=9.6.2
if [ ! -d dealii-$ver ]; then
    wget https://github.com/dealii/dealii/releases/download/v$ver/dealii-$ver.tar.gz
    tar xzf dealii-$ver.tar.gz 
fi
cd dealii-$ver
mkdir build && cd build
cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="-march=native -std=c++17" -DCMAKE_C_FLAGS=-march=native -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF         -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/lib/kokkos/v4.6.00/install -DCMAKE_BUILD_TYPE=Release -DDEAL_II_CXX_FLAGS_RELEASE=-O2 -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=CC -DCMAKE_Fortran_COMPILER=ftn -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/lib/p4est/v2.8.7/ -DDEAL_II_WITH_LAPACK=ON -DLAPACK_DIR="$OLCF_OPENBLAS_ROOT;$SCALAPACK_ROOT" -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$OLCF_OPENBLAS_ROOT/lib/libopenblas.so" -DCMAKE_INSTALL_PREFIX=../install /lustre/orion/stf006/proj-shared/raghavan/code/lib/dealii
mkae -j16
make install
mv $INST/*.log $INST/share/deal.II/
mv $INST/*.md $INST/share/deal.II/
cd $WD


DFTD4_PATH=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/lib/dftd4/v3.7.0/install
SCALAPACK_ROOT=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/lib/scalapack/v2.2.2/install
ELPA_PATH=/lustre/orion/stf006/proj-shared/raghavan/compile/frontier/lib/elpa/v2025.01.001/install
DCCL_PATH=$ROCM_PATH/include/rccl
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SCALAPACK_ROOT/lib

cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_CXX_FLAGS_RELEASE="$cxx_flagsRelease" -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=OFF -DWITH_TORCH=OFF -DELPA_INCLUDE_DIR="$ELPA_PATH/include/elpa-2025.01.001/" -DCMAKE_PREFIX_PATH="$SCALAPACK_ROOT;$ELPA_PATH;$DCCL_PATH" -DWITH_GPU=ON -DGPU_LANG=hip -DGPU_VENDOR=amd -DWITH_GPU_AWARE_MPI=OFF -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DCMAKE_SHARED_LINKER_FLAGS="-L$ROCM_PATH/lib -lamdhip64 -L$MPICH_DIR/lib -lmpi $CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a $PE_MPICH_GTL_LIBS_amd_gfx90a" -DHIGHERQUAD_PSP=ON -DWITH_COMPLEX=OFF -DUSE_64BIT_INT=ON /lustre/orion/stf006/proj-shared/raghavan/code/exe/dftfe
make -j16
