	OS_VER=$( grep VERSION_ID /etc/os-release | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' )

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

	printf "\\nOS name: ${OS_NAME}\\n"
	printf "OS Version: ${OS_VER}\\n"
	printf "CPU speed: ${CPU_SPEED}Mhz\\n"
	printf "CPU cores: %s\\n" "${CPU_CORE}"
	printf "Physical Memory: ${MEM_MEG} Mgb\\n"
	printf "Disk install: ${DISK_INSTALL}\\n"
	printf "Disk space total: ${DISK_TOTAL%.*}G\\n"
	printf "Disk space available: ${DISK_AVAIL%.*}G\\n"

	if [ "${MEM_MEG}" -lt 7000 ]; then
		printf "Your system must have 7 or more Gigabytes of physical memory installed.\\n"
		printf "Exiting now.\\n"
		exit 1;
	fi

	if [ "${OS_VER}" -lt 25 ]; then
		printf "You must be running Fedora 25 or higher to install EOSIO.\\n"
		printf "Exiting now.\\n"
		exit 1;
	fi

	if [ "${DISK_AVAIL%.*}" -lt "${DISK_MIN}" ]; then
		printf "You must have at least %sGB of available storage to install EOSIO.\\n" "${DISK_MIN}"
		printf "Exiting now.\\n"
		exit 1;
	fi
	
	printf "\\nChecking Yum installation\\n"
	
	YUM=$( command -v yum 2>/dev/null )
	if [ -z "${YUM}" ]; then
		printf "\\nYum must be installed to compile EOS.IO.\\n"
		printf "\\nExiting now.\\n"
		exit 1;
	fi
	
	printf "Yum installation found at %s.\\n" "${YUM}"
	printf "Updating YUM.\\n"
	if ! sudo yum -y update
	then
		printf "\\nYUM update failed with the above errors.\\n"
		printf "\\nExiting now.\\n"
		exit 1;
	fi
	
	DEP_ARRAY=( git gcc.x86_64 gcc-c++.x86_64 autoconf automake libtool make cmake.x86_64 \
	bzip2.x86_64 bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 libstdc++-devel.x86_64 \
	python2-devel.x86_64 python3-devel.x86_64 mongodb.x86_64 mongodb-server.x86_64 libedit.x86_64 \
	graphviz.x86_64 doxygen.x86_64 )
	COUNT=1
	DISPLAY=""
	DEP=""

	printf "\\nChecking YUM for installed dependencies.\\n\\n"

	for (( i=0; i<${#DEP_ARRAY[@]}; i++ ));
	do
		pkg=$( "${YUM}" info "${DEP_ARRAY[$i]}" 2>/dev/null | grep Repo | tr -s ' ' | cut -d: -f2 | sed 's/ //g' )

		if [ "$pkg" != "@System" ]; then
			DEP=$DEP" ${DEP_ARRAY[$i]} "
			DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n"
			printf "Package %s ${bldred} NOT ${txtrst} found.\\n" "${DEP_ARRAY[$i]}"
			(( COUNT++ ))
		else
			printf "Package %s found.\\n" "${DEP_ARRAY[$i]}"
			continue
		fi
	done		

	if [ ${COUNT} -gt 1 ]; then
		printf "\\nThe following dependencies are required to install EOSIO.\\n"
		printf "\\n${DISPLAY}\\n\\n"
		printf "Do you wish to install these dependencies?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* ) 
					printf "\\n\\nInstalling dependencies\\n\\n"
					if ! sudo yum -y install ${DEP}
					then
						printf "\\nYUM dependency installation failed.\\n"
						printf "\\nExiting now.\\n"
						exit 1;
					else
						printf "\\nYUM dependencies installed successfully.\\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else 
		printf "\\nNo required YUM dependencies to install.\\n"
	fi

	if [ "${ENABLE_COVERAGE_TESTING}" = true ]; then
		printf "\\nCode coverage build requested."
		printf "\\nChecking perl installation.\\n"
		perl_bin=$( command -v perl 2>/dev/null )
		if [ -z "${perl_bin}" ]; then
			printf "\\nInstalling perl.\\n"
			if ! sudo "${YUM}" -y install perl
			then
				printf "\\nUnable to install perl at this time.\\n"
				printf "\\nExiting now.\\n\\n"
				exit 1;
			fi
		else
			printf "Perl installation found at %s.\\n" "${perl_bin}"
		fi
		printf "\\nChecking LCOV installation."
		if [ ! -e "/usr/local/bin/lcov" ]; then
			printf "\\nLCOV installation not found.\\n"
			printf "Installing LCOV.\\n"
			if ! cd "${TEMP_DIR}"
			then
				printf "\\nUnable to enter %s. Exiting now.\\n" "${TEMP_DIR}"
				exit 1;
			fi
			if ! git clone "https://github.com/linux-test-project/lcov.git"
			then
				printf "\\nUnable to clone LCOV at this time.\\n"
				printf "Exiting now.\\n\\n"
				exit 1;
			fi
			if ! cd "${TEMP_DIR}/lcov"
			then
				printf "\\nUnable to enter %s/lcov. Exiting now.\\n" "${TEMP_DIR}"
				exit 1;
			fi
			if ! sudo make install
			then
				printf "\\nUnable to install LCOV at this time.\\n"
				printf "Exiting now.\\n\\n"
				exit 1;
			fi
			rm -rf "${TEMP_DIR}/lcov"
			printf "\\nSuccessfully installed LCOV.\\n\\n"
		else
			printf "\\nLCOV installation found @ /usr/local/bin.\\n"
		fi
	fi

	if [ -d "${HOME}/opt/boost_1_67_0" ]; then
		if ! mv "${HOME}/opt/boost_1_67_0" "$BOOST_ROOT"
		then
			printf "\\nUnable to move directory %s/opt/boost_1_67_0 to %s.\\n" "${HOME}" "${BOOST_ROOT}"
			printf "\\nExiting now.\\n"
			exit 1
		fi
		if [ -d "$BUILD_DIR" ]; then
			if ! rm -rf "$BUILD_DIR"
			then
			printf "Unable to remove directory %s. Please remove this directory and run this script %s again. 0\\n" "$BUILD_DIR" "${BASH_SOURCE[0]}"
			printf "Exiting now.\\n\\n"
			exit 1;
			fi
		fi
	fi

	printf "\\nChecking boost library installation.\\n"
	BVERSION=$( grep "BOOST_LIB_VERSION" "${BOOST_ROOT}/include/boost/version.hpp" 2>/dev/null \
	| tail -1 | tr -s ' ' | cut -d\  -f3 | sed 's/[^0-9\._]//gI' )
	if [ "${BVERSION}" != "1_67" ]; then
		printf "Removing existing boost libraries in %s/opt/boost* .\\n" "${HOME}"
		if ! rm -rf "${HOME}"/opt/boost*
		then
			printf "\\nUnable to remove deprecated boost libraries at this time.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		printf "Installing boost libraries.\\n"
		if ! cd "${TEMP_DIR}"
		then
			printf "\\nUnable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		STATUS=$( curl -LO -w '%{http_code}' --connect-timeout 30 https://dl.bintray.com/boostorg/release/1.67.0/source/boost_1_67_0.tar.bz2 )
		if [ "${STATUS}" -ne 200 ]; then
			printf "Unable to download Boost libraries at this time.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf "${TEMP_DIR}/boost_1_67_0.tar.bz2"
		then
			printf "\\nUnable to unarchive file %s/boost_1_67_0.tar.bz2.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -f  "${TEMP_DIR}/boost_1_67_0.tar.bz2"
		then
			printf "\\nUnable to remove file %s/boost_1_67_0.tar.bz2.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/boost_1_67_0/"
		then
			printf "\\nUnable to enter directory %s/boost_1_67_0.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! "${TEMP_DIR}"/boost_1_67_0/bootstrap.sh "--prefix=${BOOST_ROOT}"
		then
			printf "\\nInstallation of boost libraries failed. 0\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! "${TEMP_DIR}"/boost_1_67_0/b2 -j"${CPU_CORE}" install
		then
			printf "\\nInstallation of boost libraries failed. 1\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/boost_1_67_0"
		then
			printf "\\nUnable to remove directory %s/boost_1_67_0. 1\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if [ -d "$BUILD_DIR" ]; then
			if ! rm -rf "$BUILD_DIR"
			then
			printf "Unable to remove directory %s. Please remove this directory and run this script %s again. 0\\n" "$BUILD_DIR" "${BASH_SOURCE[0]}"
			printf "Exiting now.\\n\\n"
			exit 1;
			fi
		fi
		printf "\\nBoost 1.67.0 successfully installed at %s/opt/boost_1_67_0.\\n\\n" "${HOME}"
	else
		printf "Boost 1.67.0 found at %s/opt/boost_1_67_0.\\n" "${HOME}"
	fi

	printf "\\nChecking MongoDB C++ driver installation.\\n"
	MONGO_INSTALL=true
    if [ -e "/usr/local/lib64/libmongocxx-static.a" ]; then
		MONGO_INSTALL=false
		if [ ! -f /usr/local/lib64/pkgconfig/libmongocxx-static.pc ]; then
			MONGO_INSTALL=true
		else
			if ! version=$( grep "Version:" /usr/local/lib64/pkgconfig/libmongocxx-static.pc | tr -s ' ' | awk '{print $2}' )
			then
				printf "Unable to determine mongodb-cxx-driver version.\\n"
				printf "Exiting now.\\n\\n"
				exit 1;
			fi
			maj=$( echo "${version}" | cut -d'.' -f1 )
			min=$( echo "${version}" | cut -d'.' -f2 )
			if [ "${maj}" -gt 3 ]; then
				MONGO_INSTALL=true
			elif [ "${maj}" -eq 3 ] && [ "${min}" -lt 3 ]; then
				MONGO_INSTALL=true
			fi
		fi
	fi

    if [ $MONGO_INSTALL == "true" ]; then
		if ! cd "${TEMP_DIR}"
		then
			printf "Unable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		STATUS=$( curl -LO -w '%{http_code}' --connect-timeout 30 https://github.com/mongodb/mongo-c-driver/releases/download/1.10.2/mongo-c-driver-1.10.2.tar.gz )
		if [ "${STATUS}" -ne 200 ]; then
			if ! rm -f "${TEMP_DIR}/mongo-c-driver-1.10.2.tar.gz"
			then
				printf "Unable to remove file %s/mongo-c-driver-1.10.2.tar.gz.\\n" "${TEMP_DIR}"
			fi
			printf "Unable to download MongoDB C driver at this time.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf mongo-c-driver-1.10.2.tar.gz
		then
			printf "Unable to unarchive file %s/mongo-c-driver-1.10.2.tar.gz.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -f "${TEMP_DIR}/mongo-c-driver-1.10.2.tar.gz"
		then
			printf "Unable to remove file mongo-c-driver-1.10.2.tar.gz.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}"/mongo-c-driver-1.10.2
		then
			printf "Unable to cd into directory %s/mongo-c-driver-1.10.2.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! mkdir cmake-build
		then
			printf "Unable to create directory %s/mongo-c-driver-1.10.2/cmake-build.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd cmake-build
		then
			printf "Unable to enter directory %s/mongo-c-driver-1.10.2/cmake-build.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_BSON=ON \
		-DENABLE_SSL=OPENSSL -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON ..
		then
			printf "Configuring MongoDB C driver has encountered the errors above.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! make -j"${CPU_CORE}"
		then
			printf "Error compiling MongoDB C driver.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make install
		then
			printf "Error installing MongoDB C driver.\\nMake sure you have sudo privileges.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}"
		then
			printf "Unable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/mongo-c-driver-1.10.2"
		then
			printf "Unable to remove directory %s/mongo-c-driver-1.10.2.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! git clone https://github.com/mongodb/mongo-cxx-driver.git --branch releases/v3.3 --depth 1
		then
			printf "Unable to clone MongoDB C++ driver at this time.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/mongo-cxx-driver/build"
		then
			printf "Unable to enter directory %s/mongo-cxx-driver/build.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
		then
			printf "Cmake has encountered the above errors building the MongoDB C++ driver.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make -j"${CPU_CORE}"
		then
			printf "Error compiling MongoDB C++ driver.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make install
		then
			printf "Error installing MongoDB C++ driver.\\nMake sure you have sudo privileges.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}"
		then
			printf "Unable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo rm -rf "${TEMP_DIR}/mongo-cxx-driver"
		then
			printf "Unable to remove directory %s/mongo-cxx-driver.\\n" "${TEMP_DIR}" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		printf "Mongo C++ driver installed at /usr/local/lib64/libmongocxx-static.a.\\n"
	else
		printf "Mongo C++ driver found at /usr/local/lib64/libmongocxx-static.a.\\n"
	fi

	printf "\\nChecking LLVM with WASM support installation.\\n"
	if [ ! -d "${HOME}/opt/wasm/bin" ]; then
		printf "Installing LLVM & WASM\\n"
		if ! cd "${TEMP_DIR}"
		then
			printf "\\nUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/llvm-compiler"  2>/dev/null
		then
			printf "\\nUnable to create directory %s/llvm-compiler.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler"
		then
			printf "\\nUnable to enter directory %s/llvm-compiler.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/llvm.git
		then
			printf "Unable to clone llvm repo @ https://github.com/llvm-mirror/llvm.git.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm"
		then
			printf "\\nUnable to enter directory %s/llvm-compiler/llvm.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! $(curl https://bugzilla.redhat.com/attachment.cgi?id=1389687 | git apply)
		then
			printf "\\nUnable to apply patch https://bugzilla.redhat.com/attachment.cgi?id=1389687.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm/tools"
		then
			printf "\\nUnable to enter directory %s/llvm-compiler/llvm/tools.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/clang.git
		then
			printf "Unable to clone clang repo @ https://github.com/llvm-mirror/clang.git.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm"
		then
			printf "\\nUnable to enter directory %s/llvm-compiler/llvm.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/llvm-compiler/llvm/build"
		then
			printf "\\nUnable to create directory %s/llvm-compiler/llvm/build.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm/build"
		then
			printf "\\nUnable to enter directory %s/llvm-compiler/llvm/build.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${HOME}/opt/wasm" -DLLVM_ENABLE_RTTI=1 \
		-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly -DCMAKE_BUILD_TYPE=Release ../
		then
			printf "Cmake compiling LLVM/Clang with WASM support has exited with the above errors.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! make -j"${JOBS}"
		then
			printf "Make compiling LLVM/Clang with WASM support has exited with the above errors.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! make install
		then
			printf "Make installing LLVM/Clang with WASM support has exited with the above errors.\\n"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/llvm-compiler" 2>/dev/null
		then
			printf "\\nUnable to remove directory %s/llvm-compiler.\\n" "${TEMP_DIR}"
			printf "\\nExiting now.\\n"
			exit 1;
		fi
		printf "\\nWASM successfully installed at %s/opt/wasm\\n\\n" "${HOME}"
	else
		printf "\\nWASM found @ %s/opt/wasm\\n\\n" "${HOME}"
	fi

	function print_instructions()
	{
		printf "\\n%s -f %s &\\n" "$( command -v mongod )" "${MONGOD_CONF}"
		printf "cd %s; make test\\n\\n" "${BUILD_DIR}"
	return 0;
	}
