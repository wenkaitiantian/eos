#include "common.hpp"

#include <eosiolib/chain.h>

namespace identity {

   bool identity_base::is_trusted_by( name trusted, name by ) {
      trust_table t( _self, by.value );
      return t.find( trusted.value ) != t.end();
   }

   bool identity_base::is_trusted( name acnt ) {
      capi_name active_producers[21];
      auto active_prod_size = get_active_producers( active_producers, sizeof(active_producers) );
      auto count = active_prod_size / sizeof(name);
      for( size_t i = 0; i < count; ++i ) {
         if( active_producers[i] == acnt.value )
            return true;
      }
      for( size_t i = 0; i < count; ++i ) {
         if( is_trusted_by( acnt, name{active_producers[i]} ) )
            return true;
      }
      return false;
   }

}
