`timescale 1ns/1ps

module floor_5_ele_tb;

parameter NUM_FLOOR   = 5;
parameter FLOOR_WIDTH = $clog2(NUM_FLOOR);



localparam CLK_PERIOD  = 10;
localparam MOVE_DELAY  = 2;
localparam DOOR_DELAY  = 3;

localparam STEP_TIME   = (MOVE_DELAY + 1) * CLK_PERIOD; // time to move 1 floor  = 30ns
localparam DOOR_TIME   = (DOOR_DELAY + 1) * CLK_PERIOD; // time door stays open = 40ns
localparam MARGIN      = 2 * CLK_PERIOD;                // buffer for state-transition latency = 20ns

reg clk;
reg rst;
reg emergency;
reg [FLOOR_WIDTH-1:0] target_floor;

wire move_up;
wire move_down;
wire door_open;

// Debug outputs
wire [1:0] dbg_state;
wire [FLOOR_WIDTH-1:0] dbg_current_floor;
wire [NUM_FLOOR-1:0] dbg_pending_request;
wire [FLOOR_WIDTH-1:0] dbg_target_request;
wire dbg_request_available;
wire dbg_direction;

//========================================================
// DUT
//========================================================

floor_5_ele DUT(
    .clk(clk),
    .rst(rst),
    .emergency(emergency),
    .target_floor(target_floor),

    .move_up(move_up),
    .move_down(move_down),
    .door_open(door_open),

    .dbg_state(dbg_state),
    .dbg_current_floor(dbg_current_floor),
    .dbg_pending_request(dbg_pending_request),
    .dbg_target_request(dbg_target_request),
    .dbg_request_available(dbg_request_available),
    .dbg_direction(dbg_direction)
);

//========================================================
// Clock
//========================================================

always #(CLK_PERIOD/2) clk = ~clk;

//========================================================
// GTKWave
//========================================================

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, floor_5_ele_tb);
end

//========================================================
// Monitor
//========================================================

initial begin
    $monitor("T=%0t | Floor=%0d | Target=%0d | Pending=%b | State=%0d | Dir=%b | UP=%b DOWN=%b DOOR=%b",
             $time,
             dbg_current_floor,
             dbg_target_request,
             dbg_pending_request,
             dbg_state,
             dbg_direction,
             move_up,
             move_down,
             door_open);
end

//========================================================
// Bounds-checked floor request
//
// This is the single place that ever writes to target_floor.
// Any attempt to request a floor outside [0, NUM_FLOOR-1] is
// rejected here and flagged loudly, so an invalid floor code
// (5, 6, or 7 for this 3-bit/5-floor config) can never reach
// the DUT from this testbench, whether by a typo or a copy-paste
// mistake in a test case.
//========================================================
task request_floor(input integer floor);
begin
    if (floor < 0 || floor >= NUM_FLOOR) begin
        $display("  [TB GUARD] Refusing to drive invalid floor %0d (valid range is 0..%0d) at T=%0t",
                  floor, NUM_FLOOR-1, $time);
    end
    else begin
        target_floor = floor[FLOOR_WIDTH-1:0];
    end
end
endtask

//========================================================
// Test Sequence
//========================================================

initial begin

    clk = 0;
    rst = 1;
    emergency = 0;
    target_floor = 0;

    //-------------------------
    // Reset
    //-------------------------
    #(CLK_PERIOD*2);
    rst = 0;

    //-------------------------------------------------
    // Test 1 : Ground -> Floor 4, with two mid-flight
    //          requests added while still moving.
    //          Path: 0 -> 2 (stop) -> 3 (stop) -> 4 (stop)
    //          3 stops, 4 floor-steps total.
    //-------------------------------------------------

    $display("\n========== TEST 1 ==========");
    request_floor(4);

    // add floor 2 after ~1 step of travel
    #(STEP_TIME);
    request_floor(2);

    // add floor 3 after another step
    #(STEP_TIME);
    request_floor(3);

    // remaining time to finish: 4 steps + 3 door stops + margin,
    // minus the 2*STEP_TIME already elapsed above
    #(4*STEP_TIME + 3*DOOR_TIME + MARGIN - 2*STEP_TIME);

    //-------------------------------------------------
    // Test 2 : Go down from floor 4, add a stop at
    //          floor 0 while still descending.
    //          Path: 4 -> 1 (stop) -> 0 (stop)
    //          2 stops, 4 floor-steps total.
    //-------------------------------------------------

    $display("\n========== TEST 2 ==========");
    request_floor(1);

    // request floor 0 partway through the descent
    #(2*STEP_TIME);
    request_floor(0);

    #(4*STEP_TIME + 2*DOOR_TIME + MARGIN - 2*STEP_TIME);

    //-------------------------------------------------
    // Test 3 : Same-floor request - door should open
    //          directly with zero travel steps.
    //-------------------------------------------------

    $display("\n========== TEST 3 ==========");
    request_floor(dbg_current_floor);

    #(DOOR_TIME + MARGIN);

    //-------------------------------------------------
    // Test 4 : Emergency stop mid-travel, then resume.
    //          Path: current -> 4 (2 steps, 1 stop)
    //-------------------------------------------------

    $display("\n========== TEST 4 ==========");
    request_floor(4);

    #(STEP_TIME);
    emergency = 1;

    // hold emergency for a bit, elevator must freeze here
    #(2*CLK_PERIOD);
    emergency = 0;

    #(2*STEP_TIME + DOOR_TIME + MARGIN);

    //-------------------------------------------------
    // Test 5 : Multiple simultaneous-ish requests
    //          (SCAN should reorder them by proximity).
    //          Starting at floor 4, requests: 1, 3, 2
    //          Expected service order going down: nearest first.
    //          Worst case distance: up to 4 steps each way,
    //          3 stops total -> budget generously but not wastefully.
    //-------------------------------------------------

    $display("\n========== TEST 5 ==========");

    request_floor(4);
    #(CLK_PERIOD*2);

    request_floor(1);
    #(CLK_PERIOD*2);

    request_floor(3);
    #(CLK_PERIOD*2);

    request_floor(2);

    #(8*STEP_TIME + 3*DOOR_TIME + MARGIN);

    //-------------------------------------------------
    // Test 6 : Invalid floor codes must be rejected by
    //          the testbench guard itself (5, 6, 7 for
    //          this 3-bit-wide / 5-floor configuration).
    //-------------------------------------------------

    $display("\n========== TEST 6 : invalid floor guard ==========");
    request_floor(5);
    request_floor(6);
    request_floor(7);
    #(4*CLK_PERIOD);

    $display("\n========== SIMULATION COMPLETED at T=%0t ==========", $time);

    $finish;

end

endmodule
