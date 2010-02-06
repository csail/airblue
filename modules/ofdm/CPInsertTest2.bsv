import Controls::*;
import CPInsert::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import WiFiPreambles::*;
import Vector::*;

typedef Bool WiFiCtrl;

function CPInsertCtrl mapWiFiCPCtrl(WiFiCtrl ctrl);
   return ctrl ? tuple2(SendLong, CP0) : tuple2(SendNone, CP0);
endfunction


// (* synthesize *)
module mkWiFiCPInsert(CPInsert#(WiFiCtrl,64,1,15));
   let cpInsert <- mkCPInsert(mapWiFiCPCtrl,
			      getShortPreambles,
			      getLongPreambles);
   return cpInsert;
endmodule

