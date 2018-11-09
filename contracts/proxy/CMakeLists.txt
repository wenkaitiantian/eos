cmake_minimum_required( VERSION 3.5 )
project( proxy_example VERSION 1.0.0 )

set( CMAKE_CXX_STANDARD 17 )

find_package( eosio.cdt )

include_directories( ${MYPROJECT_DIR}../ )

add_contract( proxy proxy proxy.cpp )
