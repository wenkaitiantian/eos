	OS_VER=$( grep VERSION_ID /etc/os-release | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' \
	| cut -d'.' -f1 )

	MEM_MEG=$( free -m | sed -n 2p | tr -s ' ' | cut -d\  -f2 )
	CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
	CPU_CORE=$( lscpu -pCPU | grep -v "#" | wc -l )
	MEM_GIG=$(( ((MEM_MEG / 1000) / 2) ))
	JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

	DISK_INSTALL=$( df -h . | tail -1 | tr -s ' ' | cut -d\  -f1 )
	DISK_TOTAL_KB=$( df . | tail -1 | awk '{print $2}' )
	DISK_AVAIL_KB=$( df . | tail -1 | awk '{print $4}' )
	DISK_TOTAL=$(( DISK_TOTAL_KB / 1048576 ))
	DISK_AVAIL=$(( DISK_AVAIL_KB / 1048576 ))

	# Enter working directory
	cd $SRC_LOCATION

	printf "\\n\\tOS name: %s\\n" "${OS_NAME}"
	printf "\\tOS Version: %s\\n" "${OS_VER}"
	printf "\\tCPU speed: %sMhz\\n" "${CPU_SPEED}"
	printf "\\tCPU cores: %s\\n" "${CPU_CORE}"
	printf "\\tPhysical Memory: %s Mgb\\n" "${MEM_MEG}"
	printf "\\tDisk install: %s\\n" "${DISK_INSTALL}"
	printf "\\tDisk space total: %sG\\n" "${DISK_TOTAL%.*}"
	printf "\\tDisk space available: %sG\\n" "${DISK_AVAIL%.*}"
	printf "\\tConcurrent Jobs (make -j): ${JOBS}\\n"

	if [ "${MEM_MEG}" -lt 7000 ]; then
		printf "\\n\\tYour system must have 7 or more Gigabytes of physical memory installed.\\n"
		printf "\\tExiting now.\\n\\n"
		exit 1;
	fi

	if [ "${OS_VER}" -lt 7 ]; then
		printf "\\n\\tYou must be running Centos 7 or higher to install EOSIO.\\n"
		printf "\\tExiting now.\\n\\n"
		exit 1;
	fi

	if [ "${DISK_AVAIL%.*}" -lt "${DISK_MIN}" ]; then
		printf "\\n\\tYou must have at least %sGB of available storage to install EOSIO.\\n" "${DISK_MIN}"
		printf "\\tExiting now.\\n\\n"
		exit 1;
	fi

	printf "\\n"

	printf "\\tChecking Yum installation...\\n"
	if ! YUM=$( command -v yum 2>/dev/null ); then
			printf "\\t!! Yum must be installed to compile EOS.IO !!\\n"
			printf "\\tExiting now.\\n"
			exit 1;
	fi
	printf "\\t- Yum installation found at %s.\\n" "${YUM}"

	printf "\\n\\tDo you wish to update YUM repositories?\\n\\n"
	select yn in "Yes" "No"; do
		case $yn in
			[Yy]* ) 
				printf "\\n\\n\\tUpdating...\\n\\n"
				if ! sudo "${YUM}" -y update; then
					printf "\\n\\tYUM update failed.\\n"
					printf "\\n\\tExiting now.\\n\\n"
					exit 1;
				else
					printf "\\n\\tYUM update complete.\\n"
				fi
			break;;
			[Nn]* ) echo "Proceeding without update!";;
			* ) echo "Please type 1 for yes or 2 for no.";;
		esac
	done

	printf "\\tChecking installation of Centos Software Collections Repository...\\n"
	SCL=$( rpm -qa | grep -E 'centos-release-scl-[0-9].*' )
	if [ -z "${SCL}" ]; then
		printf "\\t - Do you wish to install and enable this repository?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* )
					printf "\\tInstalling SCL...\\n"
					if ! sudo "${YUM}" -y --enablerepo=extras install centos-release-scl 2>/dev/null; then
						printf "\\t!! Centos Software Collections Repository installation failed !!\\n"
						printf "\\tExiting now.\\n\\n"
						exit 1;
					else
						printf "\\tCentos Software Collections Repository installed successfully.\\n"
					fi
				break;;
				[Nn]* ) echo "\\tUser aborting installation of required Centos Software Collections Repository, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else
		printf "\\t - ${SCL} found.\\n"
	fi

	printf "\\tChecking installation of devtoolset-7...\\n"
	DEVTOOLSET=$( rpm -qa | grep -E 'devtoolset-7-[0-9].*' )
	if [ -z "${DEVTOOLSET}" ]; then
		printf "\\tDo you wish to install devtoolset-7?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* )
					printf "\\tInstalling devtoolset-7...\\n"
					if ! sudo "${YUM}" install -y devtoolset-7 2>/dev/null; then
							printf "\\t!! Centos devtoolset-7 installation failed !!\\n"
							printf "\\tExiting now.\\n"
							exit 1;
					else
							printf "\\tCentos devtoolset installed successfully.\\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of devtoolset-7. Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else
		printf "\\t - ${DEVTOOLSET} found.\\n"
	fi
	printf "\\tEnabling Centos devtoolset-7...\\n"
	if ! source "/opt/rh/devtoolset-7/enable" 2>/dev/null; then
		printf "\\t!! Unable to enable Centos devtoolset-7 at this time !!\\n"
		printf "\\tExiting now.\\n\\n"
		exit 1;
	fi
	printf "\\tCentos devtoolset-7 successfully enabled.\\n"

	printf "\\n"

	DEP_ARRAY=( git autoconf automake libtool make bzip2 \
                 bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 \
                 ocaml.x86_64 doxygen libicu-devel.x86_64 python33.x86_64 python-devel.x86_64 \
                 gettext-devel.x86_64 file sudo )
	COUNT=1
	DISPLAY=""
	DEP=""
	printf "\\tChecking YUM for installed dependencies.\\n"
	for (( i=0; i<${#DEP_ARRAY[@]}; i++ )); do
		pkg=$( "${YUM}" info "${DEP_ARRAY[$i]}" 2>/dev/null | grep Repo | tr -s ' ' | cut -d: -f2 | sed 's/ //g' )
		if [ "$pkg" != "installed" ]; then
			DEP=$DEP" ${DEP_ARRAY[$i]} "
			DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n\\t"
			printf "\\t!! Package %s ${bldred} NOT ${txtrst} found !!\\n" "${DEP_ARRAY[$i]}"
			(( COUNT++ ))
		else
			printf "\\t - Package %s found.\\n" "${DEP_ARRAY[$i]}"
			continue
		fi
	done
	printf "\\n"
	if [ "${COUNT}" -gt 1 ]; then
		printf "\\tThe following dependencies are required to install EOSIO.\\n"
		printf "\\t${DISPLAY}\\n\\n"
		printf "\\tDo you wish to install these dependencies?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* )
					printf "\\tInstalling dependencies\\n\\n"
					if ! sudo "${YUM}" -y install ${DEP}; then
						printf "\\t!! YUM dependency installation failed !!\\n"
						printf "\\tExiting now.\\n"
						exit 1;
					else
						printf "\\tYUM dependencies installed successfully.\\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else
		printf "\\t - No required YUM dependencies to install.\\n"
	fi
	printf "\\n"


	printf "\\n\\tChecking CMAKE installation...\\n"
    if [ -z "$(command -v cmake 2>/dev/null)" ]; then
		printf "\\tInstalling CMAKE...\\n"
		curl -LO https://cmake.org/files/v${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}/cmake-${CMAKE_VERSION}.tar.gz \
    	&& tar xf cmake-${CMAKE_VERSION}.tar.gz \
    	&& cd cmake-${CMAKE_VERSION} \
    	&& ./bootstrap \
    	&& make -j$( nproc ) \
    	&& make install \
    	&& cd .. \
    	&& rm -f cmake-${CMAKE_VERSION}.tar.gz
		printf "\\tCMAKE successfully installed @ %s.\\n\\n"
	else
		printf "\\tCMAKE found @ $(command -v cmake 2>/dev/null).\\n"
	fi


	printf "\\n\\tChecking Boost library (${BOOST_VERSION}) installation...\\n"
    if [ ! -d ${SRC_LOCATION}/boost_${BOOST_VERSION} ]; then
		printf "\\tInstalling Boost library...\\n"
		curl -LO https://dl.bintray.com/boostorg/release/${BOOST_VERSION_MAJOR}.${BOOST_VERSION_MINOR}.${BOOST_VERSION_PATCH}/source/boost_${BOOST_VERSION}.tar.bz2 \
		&& tar -xf boost_${BOOST_VERSION}.tar.bz2 \
		&& cd boost_${BOOST_VERSION}/ \
		&& ./bootstrap.sh "--prefix=${SRC_LOCATION}/boost_${BOOST_VERSION}" \
		&& ./b2 -q -j$( nproc ) install \
		&& cd .. \
		&& rm -f boost_${BOOST_VERSION}.tar.bz2
		printf "\\tBoost library successfully installed @ %s.\\n\\n"
	else
		printf "\\tBoost library found with correct version.\\n"
	fi


	printf "\\n"


	printf "\\n\\tChecking MongoDB installation...\\n"
    if [ ! -e "${MONGODB_CONF}" ]; then
		printf "\\tInstalling Boost library...\\n"
		curl -OL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& tar -xzvf mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& mv ${SRC_LOCATION}/mongodb-linux-x86_64-amazon-${MONGODB_VERSION} /opt/mongodb \
		&& mkdir /opt/mongodb/data \
		&& mkdir /opt/mongodb/log \
		&& touch /opt/mongodb/log/mongod.log \
		&& rm -f mongodb-linux-x86_64-amazon-${MONGODB_VERSION}.tgz \
		&& mv ${SOURCE_DIR}/scripts/mongod.conf /opt/mongodb/mongod.conf \
		&& mkdir -p /data/db
		printf "\\tMongoDB successfully installed @ %s.\\n\\n"
	else
		printf "\\MongoDB found with correct version.\\n"
	fi

	
	printf "\\tChecking MongoDB C driver installation...\\n"
	if [ ! -e "${SRC_LOCATION}/mongo-c-driver-${MONGO_C_DRIVER_VERSION}" ]; then
		printf "\\tInstalling MongoDB C driver...\\n"
		curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/${MONGO_C_DRIVER_VERSION}/mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz \
		&& tar -xf mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz \
		&& cd mongo-c-driver-${MONGO_C_DRIVER_VERSION} \
		&& ./configure --enable-static --with-libbson=bundled --enable-ssl=openssl --disable-automatic-init-and-cleanup --prefix=/usr/local \
		&& make -j$(nproc) \
		&& make install \
		&& cd .. \
		&& rm mongo-c-driver-${MONGO_C_DRIVER_VERSION}.tar.gz
		printf "\\tMongoDB C driver successfully installed @ %s.\\n\\n"
	else
		printf "\\MongoDB C driver found with correct version.\\n"
	fi
	printf "\\tChecking MongoDB C++ driver installation...\\n"
	if [ ! -e "${SRC_LOCATION}/mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION}" ]; then
		printf "\\tInstalling MongoDB C++ driver...\\n"
		git clone https://github.com/mongodb/mongo-cxx-driver.git --branch releases/v${MONGO_CXX_DRIVER_VERSION} --depth 1 mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION} \
		&& cd mongo-cxx-driver-${MONGO_CXX_DRIVER_VERSION}/build \
		&& cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. \
		&& make -j$(nproc) VERBOSE=1 \
		&& make install \
		&& cd ../..
		printf "\\tMongoDB C++ driver successfully installed @ %s.\\n\\n"
	else
		printf "\\MongoDB C++ driver found with correct version.\\n"
	fi

	printf "\\n"

	printf "\\tChecking LLVM with WASM support...\\n"
	if [ ! -d "${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION}" ]; then
		printf "\\tInstalling LLVM with WASM...\\n"
		git clone --depth 1 --single-branch --branch ${LLVM_CLANG_VERSION} https://github.com/llvm-mirror/llvm.git llvm-${LLVM_CLANG_VERSION} \
		&& cd llvm-${LLVM_CLANG_VERSION}/tools \
		&& git clone --depth 1 --single-branch --branch ${LLVM_CLANG_VERSION} https://github.com/llvm-mirror/clang.git clang-${LLVM_CLANG_VERSION} \
		&& cd .. \
		&& mkdir build \
		&& cd build \
		&& cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=.. -DLLVM_TARGETS_TO_BUILD= -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly -DLLVM_ENABLE_RTTI=1 -DCMAKE_BUILD_TYPE=Release ../ \
		&& make -j1 \
		&& make install \
		&& cd ../..
		printf "\\tWASM compiler successfully installed at ${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION}\\n"
	else
		printf "\\t - WASM found at ${SRC_LOCATION}/llvm-${LLVM_CLANG_VERSION}\\n"
	fi

	printf "\\n"

	function print_instructions()
	{
		printf "\\t%s -f %s &\\n" "$( command -v mongod )" "${MONGODB_CONF}"
		printf "\\tsource /opt/rh/python33/enable\\n"
		printf '\texport PATH=/opt/mongodb/bin:$PATH\n'
		printf "\\tcd %s; make test\\n\\n" "${BUILD_DIR}"
		return 0
	}
