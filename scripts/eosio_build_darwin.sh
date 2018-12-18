	OS_VER=$(sw_vers -productVersion)
	OS_MAJ=$(echo "${OS_VER}" | cut -d'.' -f1)
	OS_MIN=$(echo "${OS_VER}" | cut -d'.' -f2)
	OS_PATCH=$(echo "${OS_VER}" | cut -d'.' -f3)

	MEM_GIG=$(bc <<< "($(sysctl -in hw.memsize) / 1024000000)")

	CPU_SPEED=$(bc <<< "scale=2; ($(sysctl -in hw.cpufrequency) / 10^8) / 10")
	CPU_CORE=$( sysctl -in machdep.cpu.core_count )

	DISK_INSTALL=$(df -h . | tail -1 | tr -s ' ' | cut -d\  -f1 || cut -d' ' -f1)
	blksize=$(df . | head -1 | awk '{print $2}' | cut -d- -f1)
	gbfactor=$(( 1073741824 / blksize ))
	total_blks=$(df . | tail -1 | awk '{print $2}')
	avail_blks=$(df . | tail -1 | awk '{print $4}')
	DISK_TOTAL=$((total_blks / gbfactor ))
	DISK_AVAIL=$((avail_blks / gbfactor ))

	printf "\\nOS name: ${OS_NAME}\\n"
	printf "OS Version: ${OS_VER}\\n"
	printf "CPU speed: ${CPU_SPEED}Mhz\\n"
	printf "CPU cores: %s\\n" "${CPU_CORE}"
	printf "Physical Memory: ${MEM_GIG} Gbytes\\n"
	printf "Disk install: ${DISK_INSTALL}\\n"
	printf "Disk space total: ${DISK_TOTAL}G\\n"
	printf "Disk space available: ${DISK_AVAIL}G\\n"

	if [ "${MEM_GIG}" -lt 7 ]; then
		echo "Your system must have 7 or more Gigabytes of physical memory installed."
		echo "Exiting now."
		exit 1
	fi

	if [ "${OS_MIN}" -lt 12 ]; then
		echo "You must be running Mac OS 10.12.x or higher to install EOSIO."
		echo "Exiting now."
		exit 1
	fi

	if [ "${DISK_AVAIL}" -lt "$DISK_MIN" ]; then
		echo "You must have at least ${DISK_MIN}GB of available storage to install EOSIO."
		echo "Exiting now."
		exit 1
	fi

	printf "Checking xcode-select installation\\n"
	if ! XCODESELECT=$( command -v xcode-select)
	then
		printf "\\nXCode must be installed in order to proceed.\\n\\n"
		printf "Exiting now.\\n"
		exit 1
	fi

	printf "xcode-select installation found @ \\n"
	printf "%s \\n\\n" "${XCODESELECT}"

	printf "Checking Ruby installation.\\n"
	if ! RUBY=$( command -v ruby)
	then
		printf "\\nRuby must be installed in order to proceed.\\n\\n"
		printf "Exiting now.\\n"
		exit 1
	fi

	printf "Ruby installation found @ \\n"
	printf "%s \\n\\n" "${RUBY}"

	printf "Checking Home Brew installation\\n"
	if ! BREW=$( command -v brew )
	then
		printf "Homebrew must be installed to compile EOS.IO\\n\\n"
		printf "Do you wish to install Home Brew?\\n"
		select yn in "Yes" "No"; do
			case "${yn}" in
				[Yy]* )
				"${XCODESELECT}" --install 2>/dev/null;
				if ! "${RUBY}" -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
				then
					echo "Unable to install homebrew at this time. Exiting now."
					exit 1;
				else
					BREW=$( command -v brew )
				fi
				break;;
				[Nn]* ) echo "User aborted homebrew installation. Exiting now.";
						exit 1;;
				* ) echo "Please enter 1 for yes or 2 for no.";;
			esac
		done
	fi

	printf "Home Brew installation found @\\n"
	printf "%s\\n\\n" "${BREW}"

	COUNT=1
	PERMISSION_GETTEXT=0
	DISPLAY=""
	DEP=""

	printf "Checking dependencies.\\n"
	var_ifs="${IFS}"
	IFS=","
	while read -r name tester testee brewname uri
	do
		printf "Checking %s ... " "${name}"
		if [ "${tester}" "${testee}" ]; then
			printf " %s found\\n" "${name}"
			continue
		fi
		# resolve conflict with homebrew glibtool and apple/gnu installs of libtool
		if [ "${testee}" == "/usr/local/bin/glibtool" ]; then
			if [ "${tester}" "/usr/local/bin/libtool" ]; then
				printf " %s found\\n" "${name}"
				continue
			fi
		fi
		if [ "${brewname}" = "gettext" ]; then
			PERMISSION_GETTEXT=1
		fi
		DEP=$DEP"${brewname} "
		DISPLAY="${DISPLAY}${COUNT}. ${name}\\n"
		printf " %s ${bldred}NOT${txtrst} found.\\n" "${name}"
		(( COUNT++ ))
	done < "${SOURCE_DIR}/scripts/eosio_build_dep"
	IFS="${var_ifs}"

	printf "Checking Python3 ... "
	if [  -z "$( python3 -c 'import sys; print(sys.version_info.major)' 2>/dev/null )" ]; then
		DEP=$DEP"python@3 "
		DISPLAY="${DISPLAY}${COUNT}. Python 3\\n"
		printf " python3 ${bldred}NOT${txtrst} found.\\n"
		(( COUNT++ ))
	else
		printf " Python3 found\\n"
	fi

	if [ $COUNT -gt 1 ]; then
		printf "\\nThe following dependencies are required to install EOSIO.\\n"
		printf "\\n${DISPLAY}\\n\\n"
		echo "Do you wish to install these packages?"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* )
					if [ $PERMISSION_GETTEXT -eq 1 ]; then
						sudo chown -R "$(whoami)" /usr/local/share
					fi
					"${XCODESELECT}" --install 2>/dev/null;
					printf "Updating Home Brew.\\n"
					if ! brew update
					then
						printf "Unable to update Home Brew at this time.\\n"
						printf "Exiting now.\\n\\n"
						exit 1;
					fi
					printf "Installing Dependencies.\\n"
					if ! "${BREW}" install --force ${DEP}
					then
						printf "Homebrew exited with the above errors.\\n"
						printf "Exiting now.\\n\\n"
						exit 1;
					fi
                                        if [[ "$DEP" == "llvm@4" ]]; then
                                                "${BREW}" unlink ${DEP}
					elif ! "${BREW}" unlink ${DEP} && "${BREW}" link --force ${DEP}
					then
						printf "Homebrew exited with the above errors.\\n"
						printf "Exiting now.\\n\\n"
						exit 1;
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else
		printf "\\nNo required Home Brew dependencies to install.\\n"
	fi


	printf "\\nChecking boost library installation.\\n"
	BVERSION=$( grep "#define BOOST_VERSION" "/usr/local/include/boost/version.hpp" 2>/dev/null | tail -1 | tr -s ' ' | cut -d\  -f3 )
	if [ "${BVERSION}" != "106700" ]; then
		if [ ! -z "${BVERSION}" ]; then
			printf "Found Boost Version %s.\\n" "${BVERSION}"
			printf "EOS.IO requires Boost version 1.67.\\n"
			printf "Would you like to uninstall version %s and install Boost version 1.67.\\n" "${BVERSION}"
			select yn in "Yes" "No"; do
				case $yn in
					[Yy]* )
						if "${BREW}" list | grep "boost"
						then
							printf "Uninstalling Boost Version %s.\\n" "${BVERSION}"
							if ! "${BREW}" uninstall --force boost
							then
								printf "Unable to remove boost libraries at this time. 0\\n"
								printf "Exiting now.\\n\\n"
								exit 1;
							fi
						else
							printf "Removing Boost Version %s.\\n" "${BVERSION}"
							if ! sudo rm -rf "/usr/local/include/boost"
							then
								printf "Unable to remove boost libraries at this time. 1\\n"
								printf "Exiting now.\\n\\n"
								exit 1;
							fi
							if ! sudo rm -rf /usr/local/lib/libboost*
							then
								printf "Unable to remove boost libraries at this time. 2\\n"
								printf "Exiting now.\\n\\n"
								exit 1;
							fi
						fi
					break;;
					[Nn]* ) echo "User cancelled installation of Boost libraries, Exiting now."; exit;;
					* ) echo "Please type 1 for yes or 2 for no.";;
				esac
			done
		fi
		printf "Installing boost libraries.\\n"
		if ! "${BREW}" install https://raw.githubusercontent.com/Homebrew/homebrew-core/f946d12e295c8a27519b73cc810d06593270a07f/Formula/boost.rb
		then
			printf "Unable to install boost 1.67 libraries at this time. 0\\n"
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
		printf "Boost 1.67.0 successfully installed @ /usr/local.\\n"
	else
		printf "Boost 1.67.0 found at /usr/local.\\n"
	fi

	printf "\\nChecking MongoDB C++ driver installation.\\n"
	MONGO_INSTALL=true

    if [ -e "/usr/local/lib/libmongocxx-static.a" ]; then
		MONGO_INSTALL=false
		if ! version=$( grep "Version:" /usr/local/lib/pkgconfig/libmongocxx-static.pc | tr -s ' ' | awk '{print $2}' )
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

    if [ $MONGO_INSTALL == "true" ]; then
		if ! cd "${TEMP_DIR}"
		then
			printf "Unable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! pkgconfig=$( "${BREW}" list | grep pkg-config )
		then
			if ! "${BREW}" install --force pkg-config
			then
				printf "Homebrew returned an error installing pkg-config.\\n"
				printf "Exiting now.\\n\\n"
				exit 1;
			fi
			if ! "${BREW}" unlink pkg-config && "${BREW}" link --force pkg-config
			then
				printf "Homebrew returned an error linking pkgconfig.\\n"
				printf "Exiting now.\\n\\n"
				exit 1;
			fi
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
		-DENABLE_SSL=DARWIN -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON ..
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
		if ! make -j"${CPU_CORE}"
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
		if ! rm -rf "${TEMP_DIR}/mongo-cxx-driver"
		then
			printf "Unable to remove directory %s/mongo-cxx-driver.\\n" "${TEMP_DIR}" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		printf "Mongo C++ driver installed at /usr/local/lib/libmongocxx-static.a.\\n"
	else
		printf "Mongo C++ driver found at /usr/local/lib/libmongocxx-static.a.\\n"
	fi

	printf "\\nChecking LLVM with WASM support.\\n"
	if [ ! -d /usr/local/wasm/bin ]; then
		if ! cd "${TEMP_DIR}"
		then
			printf "Unable to enter directory %s.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/wasm-compiler"
		then
			printf "Unable to create directory %s/wasm-compiler.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/wasm-compiler"
		then
			printf "Unable to enter directory %s/wasm-compiler.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/llvm.git
		then
			printf "Unable to clone llvm repo @ https://github.com/llvm-mirror/llvm.git.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/wasm-compiler/llvm/tools"
		then
			printf "Unable to enter directory %s/wasm-compiler/llvm/tools.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/clang.git
		then
			printf "Unable to clone clang repo @ https://github.com/llvm-mirror/clang.git.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/wasm-compiler/llvm"
		then
			printf "Unable to enter directory %s/wasm-compiler/llvm.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/wasm-compiler/llvm/build"
		then
			printf "Unable to create directory %s/wasm-compiler/llvm/build.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/wasm-compiler/llvm/build"
		then
			printf "Unable to enter directory %s/wasm-compiler/llvm/build.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/usr/local/wasm \
		-DLLVM_TARGETS_TO_BUILD= -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly \
		-DCMAKE_BUILD_TYPE=Release ../
		then
			printf "Error compiling LLVM/Clang with WASM support.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make -j"${CPU_CORE}" install
		then
			printf "Compiling LLVM/Clang with WASM support has exited with the error above.\\n"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo rm -rf "${TEMP_DIR}/wasm-compiler"
		then
			printf "Unable to remove directory %s/wasm-compiler.\\n" "${TEMP_DIR}"
			printf "Exiting now.\\n\\n"
			exit 1;
		fi
		printf "Successfully installed LLVM/Clang with WASM support @ /usr/local/wasm/bin/.\\n"
	else
		printf "WASM found at /usr/local/wasm/bin/.\\n"
	fi

	function print_instructions()
	{
		printf "\\n%s -f %s &\\n" "$( command -v mongod )" "${MONGODB_CONF}"
		printf "cd %s; make test\\n\\n" "${BUILD_DIR}"
	return 0
	}
