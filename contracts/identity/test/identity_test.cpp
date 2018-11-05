#include <eosiolib/action.h>
#include <eosiolib/contract.hpp>
#include <eosiolib/dispatcher.hpp>
#include <identity/interface.hpp>

namespace identity_test {
   
    //using eosio::action_meta;
   using eosio::singleton;
   using std::string;
   using std::vector;

   CONTRACT contract : public eosio::contract {
      public:
         static constexpr uint64_t code = "identitytest"_n.value;
         typedef singleton<"result"_n, uint64_t> result_table;

         using eosio::contract::contract;

         ACTION getowner( const uint64_t identity ) {
            identity::interface iface( "identity"_n );
            name owner = iface.get_owner_for_identity(current_receiver(), identity);
            result_table( "code"_n, 0 ).set( owner.value, "code"_n ); //use scope = 0 for simplicity
         }

         // public:

         // /**
         //  * Construct a new singleton object given the table's owner and the scope
         //  *
         //  * @brief Construct a new singleton object
         //  * @param code - The table's owner
         //  * @param scope - The scope of the table
         //  */
         // singleton( name code, uint64_t scope ) : _t( code, scope ) {}

         ACTION getidentity( const name account ) {
            identity::interface iface( "identity"_n );
            identity::identity_name idnt = iface.get_identity_for_account(current_receiver(), account);
            result_table( "code"_n, 0 ).set(idnt.value, "code"_n ); //use scope = 0 for simplicity
         }
   };

} /// namespace identity

EOSIO_DISPATCH( identity_test::contract, (getowner)(getidentity) );
