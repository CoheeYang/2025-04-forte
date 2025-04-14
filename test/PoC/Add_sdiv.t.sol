/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract add_sdiv is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

    /// as long as a and b are too far away() from each other, the decimal loss would occur
    // this holds for a and b are m

    int256 aMan = 1;
    int256 aExp = 19;

    int256 bMan = -1;
    int256 bExp = -66;
    



        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
    
        //(a+b)
        packedFloat a_b = Float128.add(a, b);

    function test_poc_add_sdiv() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int bMan_dec,int bExp_dec) = Float128.decode(b);

        (int a_bMan_dec,int a_bExp_dec) = Float128.decode(a_b);

        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("bMan",bMan_dec,"bExp",bExp_dec);

        emit log("a_bMan",a_bMan_dec,"a_bExp",a_bExp_dec);






    }



}
