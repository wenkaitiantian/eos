	OS_VER=$( grep VERSION_ID /etc/os-release | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' | cut -d'.' -f1 )

	MEM_MEG=$( free -m | sed -n 2p | tr -s ' ' | cut -d\  -f2 )
	CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
	CPU_CORE=$( lscpu -pCPU | grep -v "#" | wc -l )
	MEM_GIG=$(( ((MEM_MEG / 1000) / 2) ))
	JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

	DISK_TOTAL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f2 | sed 's/[^0-9]//' )
	DISK_AVAIL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f4 | sed 's/[^0-9]//' )

	printf "\\nOS name: %s\\n" "${OS_NAME}"
	printf "OS Version: %s\\n" "${OS_VER}"
	printf "CPU speed: %sMhz\\n" "${CPU_SPEED}"
	printf "CPU cores: %s\\n" "${CPU_CORE}"
	printf "Physical Memory: %sMgb\\n" "${MEM_MEG}"
	printf "Disk space total: %sGb\\n" "${DISK_TOTAL}"
	printf "Disk space available: %sG\\n" "${DISK_AVAIL}"

	if [ "${MEM_MEG}" -lt 7000 ]; then
		printf "Your system must have 7 or more Gigabytes of physical memory installed.\\n"
		printf "exiting now.\\n"
		exit 1
	fi

	if [[ "${OS_NAME}" == "Amazon Linux AMI" && "${OS_VER}" -lt 2017 ]]; then
		printf "You must be running Amazon Linux 2017.09 or higher to install EOSIO.\\n"
		printf "exiting now.\\n"
		exit 1
	fi

	if [ "${DISK_AVAIL}" -lt "${DISK_MIN}" ]; then
		printf "You must have at least %sGB of available storage to install EOSIO.\\n" "${DISK_MIN}"
		printf "exiting now.\\n"
		exit 1
	fi

	printf "\\nChecking Yum installation.\\n"
	if ! YUM=$( command -v yum 2>/dev/null )
	then
		printf "\\nYum must be installed to compile EOS.IO.\\n"
		printf "\\nExiting now.\\n"
		exit 1
	fi
	
	printf "Yum installation found at ${YUM}.\\n"

	if [[ "${OS_NAME}" == "Amazon Linux AMI" ]]; then
		DEP_ARRAY=( git gcc72.x86_64 gcc72-c++.x86_64 autoconf automake libtool make bzip2 \
		bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 libstdc++72.x86_64 \
		python27.x86_64 python36-devel.x86_64 libedit-devel.x86_64 doxygen.x86_64 graphviz.x86_64)
	else
		DEP_ARRAY=( git gcc.x86_64 gcc-c++.x86_64 autoconf automake libtool make bzip2 \
		bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 libstdc++.x86_64 \
		python3.x86_64 python3-devel.x86_64 libedit-devel.x86_64 doxygen.x86_64 graphviz.x86_64)
	fi
	COUNT=1
	DISPLAY=""
	DEP=""

	printf "\\nDo you wish to update YUM repositories?\\n\\n"
	select yn in "Yes" "No"; do
		case $yn in
			[Yy]* ) 
				printf "\\n\\nUpdating...\\n\\n"
				if ! sudo "${YUM}" -y update; then
					printf "\\nYUM update failed.\\n"
					printf "\\nExiting now.\\n\\n"
					exit 1;
				else
					printf "\\nYUM update complete.\\n"
				fi
			break;;
			[Nn]* ) echo "Proceeding without update!";;
			* ) echo "Please type 1 for yes or 2 for no.";;
		esac
	done

	printf "Checking YUM for installed dependencies.\\n"
	for (( i=0; i<${#DEP_ARRAY[@]}; i++ )); do
		pkg=$( "${YUM}" info "${DEP_ARRAY[$i]}" 2>/dev/null | grep Repo | tr -s ' ' | cut -d: -f2 | sed 's/ //g' )
		if [ "$pkg" != "installed" ]; then
			DEP=$DEP" ${DEP_ARRAY[$i]} "
			DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n"
			printf "!! Package %s ${bldred} NOT ${txtrst} found !!\\n" "${DEP_ARRAY[$i]}"
			(( COUNT++ ))
		else
			printf " - Package %s found.\\n" "${DEP_ARRAY[$i]}"
			continue
		fi
	done
	printf "\\n"
	if [ "${COUNT}" -gt 1 ]; then
		printf "The following dependencies are required to install EOSIO.\\n"
		printf "${DISPLAY}\\n\\n"
		printf "Do you wish to install these dependencies?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* )
					printf "Installing dependencies\\n\\n"
					if ! sudo "${YUM}" -y install ${DEP}; then
						printf "!! YUM dependency installation failed !!\\n"
						printf "Exiting now.\\n"
						exit 1;
					else
						printf "YUM dependencies installed successfully.\\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else
		printf " - No required YUM dependencies to install.\\n"
	fi
	
	
	printf "\\n"


	printf "Checking CMAKE installation...\\n"
    if [ -z "$(command -v cmake 2>/dev/null)" ]; then
		printf "Installing CMAKE...\\n"
		curl -LO https://cmake.org/files/v${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}/cmake-${CMAKE_VERSION}.tar.gz \
    	&& tar xf cmake-${CMAKE_VERSION}.tar.gz \
    	&& cd cmake-${CMAKE_VERSION} \
    	&& ./bootstrap \
    	&& make -j$( nproc ) \
    	&& make install \
    	&& cd .. \
    	&& rm -f cmake-${CMAKE_VERSION}.tar.gz
		printf " - CMAKE successfully installed @ %s.\\n\\n"
	else
		printf " - CMAKE found @ $(command -v cmake 2>/dev/null).\\n"
	fi


	printf "\\n"


	printf "Checking Boost library (${BOOST_VERSION}) installation...\\n"
    if [ ! -d ${SRC_LOCATION}/boost_${BOOST_VERSION} ]; then
		printf "Installing Boost library...\\n"
		curl -LO https://dl.bintray.com/boostorg/release/${BOOST_VERSION_MAJOR}.${BOOST_VERSION_MINOR}.${BOOST_VERSION_PATCH}/source/boost_${BOOST_VERSION}.tar.bz2 \
		&& tar -xf boost_${BOOST_VERSION}.tar.bz2 \
		&& cd boost_${BOOST_VERSION}/ \
		&& ./bootstrap.sh "--prefix=${SRC_LOCATION}/boost_${BOOST_VERSION}" \
		&& ./b2 -q -j$( nproc ) install \
		&& cd .. \
		&& rm -f boost_${BOOST_VERSION}.tar.bz2 \
		&& rm -rf $HOME/opt/boost \
		&& ln -s /usr/local/src/boost_${BOOST_VERSION} $HOME/opt/boost
		printf " - Boost library successfully installed @ %s.\\n\\n"
	else
		printf " - Boost library found with correct version.\\n"
	fi


	printf "\\n"


	printf "Checking MongoDB installation...\\n"
	# eosio_build.sh sets PATH with /opt/mongodb/bin
    if [ ! -e "${MONGODB_CONF}" ]; then
		printf "Installing MongoDB...\\n"
		curl -OL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& tar -xzvf mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& mv ${SRC_LOCATION}/mongodb-linux-x86_64-amazon-${MONGODB_VERSION} /opt/mongodb \
		&& mkdir /opt/mongodb/data \
		&& mkdir /opt/mongodb/log \
		&& touch /opt/mongodb/log/mongod.log \
		&& rm -f mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& mv ${SOURCE_DIR}/scripts/mongod.conf /opt/mongodb/mongod.conf \
		&& mkdir -p /data/db \
		&& mkdir -p /var/log/mongodb
		printf " - MongoDB successfully installed @ /opt/mongodb.\\n"
	else
		printf " - MongoDB found with correct version."
	fi
	printf "Checking MongoDB C driver installation...\\n"
	if [ ! -e "${SRC_LOCATION}/mongo-c-driver-${MONGO_C_DRIVER_VERSION}" ]; then
		printf "Installing MongoDB C driver...\\n"
		curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/${MONGO_C_DRIVER_VERSION}/mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz \
		&& tar -xf mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz \
		&& cd mongo-c-driver-${MONGO_C_DRIVER_VERSION} \
		&& mkdir -p cmake-build \
		&& cd cmake-build \
		&& cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_BSON=ON -DENABLE_SSL=OPENSSL -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON .. \
		&& make -j$(nproc) \
		&& make install \
		&& cd ../.. \
		&& rm mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz
		printf " - MongoDB C driver successfully installed @ .\\n"
	else
		printf " - MongoDB C driver found with correct version.\\n"
	fi
	printf "Checking MongoDB C++ driver installation...\\n"
	if [ ! -e "${SRC_LOCATION}/mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION}" ]; then
		printf "Installing MongoDB C++ driver...\\n"
		git clone https://github.com/mongodb/mongo-cxx-driver.git --branch releases/v${MONGO_CXX_DRIVER_VERSION} --depth 1 mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION} \
		&& cd mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION}/build \
		&& cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. \
		&& make -j$(nproc) VERBOSE=1 \
		&& make install \
		&& cd ../..
		printf " - MongoDB C++ driver successfully installed @ %s.\\n"
	else
		printf " - MongoDB C++ driver found with correct version.\\n"
	fi


	printf "\\n"


	printf "Checking LLVM with WASM support...\\n"
	if [ ! -d "${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION}" ]; then
		printf "Installing LLVM with WASM...\\n"
		git clone --depth 1 --single-branch --branch ${LLVM_CLANG_VERSION} https://github.com/llvm-mirror/llvm.git llvm-$LLVM_CLANG_VERSION \
		&& cd llvm-$LLVM_CLANG_VERSION/tools \
		&& git clone --depth 1 --single-branch --branch ${LLVM_CLANG_VERSION} https://github.com/llvm-mirror/clang.git clang-$LLVM_CLANG_VERSION \
		&& cd .. \
		&& mkdir build \
		&& cd build \
		&& cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=.. -DLLVM_TARGETS_TO_BUILD= -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly -DLLVM_ENABLE_RTTI=1 -DCMAKE_BUILD_TYPE=Release .. \
		&& make -j1 \
		&& make install \
		&& cd ../.. \
		&& rm -f $HOME/opt/wasm \
		&& ln -s /usr/local/src/llvm-$LLVM_CLANG_VERSION $HOME/opt/wasm
		printf " - WASM compiler successfully installed at ${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION} (Symlinked to ${HOME}/opt/wasm)\\n"
	else
		printf " - WASM found at ${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION}\\n"
	fi


	cd ..
	printf "\\n"

	function print_instructions()
	{
		printf "%s -f %s &\\n" "$( command -v mongod )" "${MONGODB_CONF}"
		printf "export PATH=/opt/mongodb/bin:$PATH\n"
		printf "cd %s; make test\\n\\n" "${BUILD_DIR}"
		return 0
	}