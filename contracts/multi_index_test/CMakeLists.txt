cmake_minimum_required( VERSION 3.5 )
project( multi_index_test_example VERSION 1.0.0 )

set( CMAKE_CXX_STANDARD 17 )

find_package( eosio.cdt )

add_contract( multi_index_test multi_index_test multi_index_test.cpp )
