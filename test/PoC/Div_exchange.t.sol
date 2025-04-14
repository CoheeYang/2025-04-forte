/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract div_exchange is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

// emit Log(«selected numbers», -87283573069964945934543471695741124773, 0, -10854273485387318471892573185999759982, 0, 8064586624949681777232594308777387474, 0) 
// emit result(«x_y_z», 57137297505895685452572314730429849956760323022080908951596686380013692691262, «x_z_y.», 57137297505895685452572314730429849956760323022080908951596686380013692691253) 
    int256 aMan = -87283573069964945934543471695741124773;
    int256 aExp = 0;
    
    int256 bMan = -10854273485387318471892573185999759982;
    int256 bExp = 0;

    int256 cMan = 8064586624949681777232594308777387474;
    int256 cExp = 0;


        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);
        
        packedFloat a_b = Float128.div(a, b,true);
        packedFloat a_b_c = Float128.div(a_b, c,true);

        packedFloat a_c = Float128.div(a, c,true);
        packedFloat a_c_b = Float128.div(a_c, b,true);


        


    function test_poc_div_exchange() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int bMan_dec,int bExp_dec) = Float128.decode(b);
        (int cMan_dec,int cExp_dec) = Float128.decode(c);

        (int a_bMan_dec,int a_bExp_dec) = Float128.decode(a_b);
        (int a_b_cMan_dec,int a_b_cExp_dec) = Float128.decode(a_b_c);

        (int a_cMan_dec,int a_cExp_dec) = Float128.decode(a_c);
        (int a_c_bMan_dec,int a_c_bExp_dec) = Float128.decode(a_c_b);



        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("bMan",bMan_dec,"bExp",bExp_dec);
        emit log("cMan",cMan_dec,"cMan",cExp_dec);

        emit log("a_bMan",a_bMan_dec,"a_bExp",a_bExp_dec);
        

        emit log("a_cMan",a_cMan_dec,"a_cExp",a_cExp_dec);
        
        emit log("a_b_cMan",a_b_cMan_dec,"a_b_cExp",a_b_cExp_dec);
        emit log("a_c_bMan",a_c_bMan_dec,"a_c_bExp",a_c_bExp_dec);
        assert(Float128.eq(a_b_c, a_c_b));



    }



}
