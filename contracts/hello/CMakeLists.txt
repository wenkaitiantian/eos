cmake_minimum_required( VERSION 3.5 )
project( hello_example VERSION 1.0.0 )

set( CMAKE_CXX_STANDARD 17 )

find_package( eosio.cdt )

add_contract( hello hello hello.cpp )
