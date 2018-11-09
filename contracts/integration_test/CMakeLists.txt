cmake_minimum_required( VERSION 3.5 )
project( integration_test_example VERSION 1.0.0 )

set( CMAKE_CXX_STANDARD 17 )

find_package( eosio.cdt )

add_contract( integration_test integration_test integration_test.cpp )
