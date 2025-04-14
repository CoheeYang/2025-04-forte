/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract Sqrt is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);



    int256 aMan = 1;
    int256 aExp = 72;

    int256 aMan_sq = aMan * aMan;
    int256 aExp_sq = aExp * 2;
    

        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat a_sq = Float128.toPackedFloat(aMan_sq, aExp_sq);

       
        packedFloat r = Float128.sqrt(a_sq);


    function test_poc_sqrt() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int aMan_sq_dec,int aExp_sq_dec) = Float128.decode(a_sq);
        (int rMan_dec,int rExp_dec) = Float128.decode(r);

        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("aMan_sq",aMan_sq_dec,"aExp_sq",aExp_sq_dec);
        emit log("rMan",rMan_dec,"rExp",rExp_dec);



        assert(Float128.eq(a, r));  
    }

}
