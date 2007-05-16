import FIFO::*;
import Vector::*;
import VParams::*;
import ShiftRegs::*;
import Parameters::*;

//This is a pipelined implementation of the traceback logic
//Parameters:
//              L = Traceback length
//    NoOfDecodes = # of decodes in 1 cycle
// PipelineStages = # of pipeline stages = L/NoOfDecodes

typedef TBLength                L;
typedef TDiv#(L,NoOfDecodes)    PipelineStages;
typedef TAdd#(NoOfDecodes,1)    CSRSize;
typedef 24                      FIFOSize;
typedef TSub#(KSz,1)            StateSize;
typedef TExp#(StateSize)        NoOfStates;

// interface
interface Traceback;
    method Action updateMemory(Vector#(NoOfStates, Bit#(1)) newPointers, Bit#(StateSize) minIndex);
    method ActionValue#(Bit#(1)) getDecodedOutput();
    method Action clear();
endinterface


(* noinline *)
//Decode 1 column
function Bit#(StateSize) decodeCol(Bit#(StateSize) currIndex, Vector#(NoOfStates,Bit#(1)) traceColumn);
    return truncate({currIndex, traceColumn[currIndex]});
endfunction

(* noinline *)
//Decode NoOfDecodes columns
function Bit#(StateSize) decode(Bit#(StateSize) currIndex, Vector#(NoOfDecodes, Vector#(NoOfStates,Bit#(1))) traceColumns);
    return foldl(decodeCol, currIndex, traceColumns);
endfunction

interface TracebackMemory;
    method Action addColumn(Vector#(NoOfStates, Bit#(1)) newPointers);
    method Vector#(PipelineStages, Vector#(CSRSize, Vector#(NoOfStates, Bit#(1)))) getAllMem();
    method Action clear();
endinterface

(* synthesize *)
module mkCSRforTB(ShiftRegs#(CSRSize, Vector#(NoOfStates, Bit#(1))));

   ShiftRegs#(CSRSize, Vector#(NoOfStates, Bit#(1))) memory <- mkCirShiftRegs;

   return memory;

endmodule // mkCSRforTB
   

(* synthesize *)
module mkTracebackMemory(TracebackMemory);
    //Traceback memory:
    //There are PipelineStages number of Circular Shift Registers (CSR)
    //Each cycle, a new column of Vector#(64, Bit#(1)) is added to the leftmost CSR
    //and the rightmost column of each CSR is added to the next CSR
    Vector#(PipelineStages, ShiftRegs#(CSRSize, Vector#(NoOfStates, Bit#(1)))) tracebackMemory <- replicateM(mkCSRforTB);
    
    method Action addColumn(Vector#(NoOfStates, Bit#(1)) newPointers);
        tracebackMemory[0].enq(newPointers);
        for(Integer i = 0; i < valueOf(PipelineStages)-1; i=i+1)
            tracebackMemory[i+1].enq(tracebackMemory[i].first());
    endmethod

    method Vector#(PipelineStages, Vector#(CSRSize, Vector#(NoOfStates, Bit#(1)))) getAllMem();
        Vector#(PipelineStages, Vector#(CSRSize, Vector#(NoOfStates, Bit#(1)))) allMem = newVector();
        for(Integer i = 0; i < valueOf(PipelineStages); i=i+1)
            allMem[i] = tracebackMemory[i].getVector();
        return allMem;
    endmethod

    method Action clear();
        for(Integer i = 0; i < valueOf(PipelineStages); i=i+1)
        begin
            tracebackMemory[i].clear();
        end
    endmethod
endmodule

(* synthesize *)
module mkTraceback(Traceback);
    TracebackMemory                                     tracebackMemory <- mkTracebackMemory();
    Vector#(PipelineStages, Reg#(Maybe#(Bit#(StateSize)))) minStateRegs <- replicateM(mkReg(tagged Invalid));
    Reg#(UInt#(TLog#(TAdd#(L,1))))                                       counter <- mkReg(0);
    FIFO#(Bit#(1))                                             outQueue <- mkSizedFIFO(valueOf(FIFOSize));

    Vector#(PipelineStages, Vector#(CSRSize, Vector#(NoOfStates, Bit#(1))))           allMem = tracebackMemory.getAllMem();
    Vector#(PipelineStages, Vector#(NoOfDecodes, Vector#(NoOfStates, Bit#(1)))) tracebackMem = newVector();
    for(Integer i = 0; i < valueOf(PipelineStages); i=i+1)
    begin
        tracebackMem[i] = newVector();
        for(Integer j = 0; j < valueOf(NoOfDecodes); j=j+1)
            tracebackMem[i][j] = allMem[i][valueOf(NoOfDecodes)-j];
    end

    method Action updateMemory(Vector#(NoOfStates, Bit#(1)) newPointers, Bit#(StateSize) minIndex);
        tracebackMemory.addColumn(newPointers);
        //$write("%t: ", $stime);
        //for(Integer i = 0; i < valueOf(NoOfStates); i=i+1)
            //$write("%b", newPointers[i]);
        //$write(" %b\n", minIndex);
        if(counter == fromInteger(valueOf(L)))
            (minStateRegs[0]) <= tagged Valid minIndex;
        else          counter <= counter+1;

        let lastStage = valueOf(PipelineStages)-1;
        for(Integer i = 0; i < lastStage; i=i+1)
        begin
            if(isValid(minStateRegs[i]._read()))
            begin
                let decColumns       = tracebackMem[i];
                let newIndex         = decode(fromMaybe(0,minStateRegs[i]._read()), decColumns);
                (minStateRegs[i+1])  <= tagged Valid newIndex;
            end
            else (minStateRegs[i+1]) <= tagged Invalid;
        end
        if(isValid(minStateRegs[lastStage]._read()))
        begin
            let decLastColumns = tracebackMem[lastStage];
            let minState = decode(fromMaybe(0,minStateRegs[lastStage]._read()), decLastColumns);
            //$write("%t: ", $stime);
            //$write("%b\n", minState);
            outQueue.enq(tpl_1(split(minState)));
        end
    endmethod 

    method ActionValue#(Bit#(1)) getDecodedOutput();
        outQueue.deq();
        return outQueue.first();
    endmethod

    method Action clear();
        tracebackMemory.clear();
        for(Integer i = 0; i < valueOf(PipelineStages); i=i+1)
            (minStateRegs[i]) <= tagged Invalid;
        counter <= 0;
        outQueue.clear();
    endmethod
endmodule



