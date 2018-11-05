/**
 *  @file
 *  @copyright defined in eos/LICENSE.txt
 */

#pragma once

#include <eosiolib/eosio.hpp>
#include <eosiolib/singleton.hpp>
#include <vector>

using namespace eosio;

namespace identity {

    typedef uint64_t identity_name;
    typedef uint64_t property_name;
    typedef uint64_t property_type_name;

    TABLE certvalue {
        property_name     property; ///< name of property, base32 encoded i64
        std::string       type; ///< defines type serialized in data
        std::vector<char> data; ///<
        std::string       memo; ///< meta data documenting basis of certification
        uint8_t           confidence = 1; ///< used to define liability for lies,
        /// 0 to delete

        property_name primary_key() { return property; }

        EOSLIB_SERIALIZE( certvalue, (property)(type)(data)(memo)(confidence) )
    };

    TABLE certrow {
        uint64_t            id;
        property_name       property;
        uint64_t            trusted;
        name                certifier;
        uint8_t             confidence = 0;
        std::string         type;
        std::vector<char>   data;
        uint64_t primary_key() const { return id; }
        /* constexpr */ static eosio::key256 key(uint64_t property, uint64_t trusted, uint64_t certifier) {
            /*
              key256 key;
              key.uint64s[0] = property;
              key.uint64s[1] = trusted;
              key.uint64s[2] = certifier;
              key.uint64s[3] = 0;
            */
            return eosio::key256::make_from_word_sequence<uint64_t>(property, trusted, certifier);
        }
        eosio::key256 get_key() const { return key(property, trusted, certifier.value); }

        EOSLIB_SERIALIZE( certrow , (property)(trusted)(certifier)(confidence)(type)(data)(id) )
    };

    TABLE identrow {
        uint64_t identity;
        name     creator;

        uint64_t primary_key() const { return identity; }

        EOSLIB_SERIALIZE( identrow , (identity)(creator) )
    };

    TABLE trustrow {
        name account;

        uint64_t primary_key() const { return account.value; }

        EOSLIB_SERIALIZE( trustrow, (account) )
    };

    typedef eosio::multi_index<"certs"_n, certrow, eosio::indexed_by< "bytuple"_n, eosio::const_mem_fun<certrow, eosio::key256, &certrow::get_key >>> certs_table;
    typedef eosio::multi_index<"ident"_n, identrow> idents_table;
    typedef eosio::singleton<"account"_n, identity_name>  accounts_table;
    typedef eosio::multi_index<"trust"_n, trustrow> trust_table;

    class identity_base : public contract {
    public:
        using contract::contract;

        bool is_trusted_by( name trusted, name by );
        bool is_trusted( name acnt );
    };
}

//EOSIO_DISPATCH( identity::identity_base, (is_trusted_by)(is_trusted) )
