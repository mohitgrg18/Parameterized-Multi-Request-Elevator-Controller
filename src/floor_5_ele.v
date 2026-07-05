// ============================================================
// Top-level Elevator Controller
// ============================================================
module floor_5_ele #(
    parameter integer NUM_FLOOR   = 5,
    parameter integer FLOOR_WIDTH = $clog2(NUM_FLOOR)
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     emergency,
    input  wire [FLOOR_WIDTH-1:0]   target_floor,

    output reg                      move_up,
    output reg                      move_down,
    output reg                      door_open,

    // Debug/observability outputs (handy for waveform viewing)
    output wire [1:0]               dbg_state,
    output wire [FLOOR_WIDTH-1:0]   dbg_current_floor,
    output wire [NUM_FLOOR-1:0]     dbg_pending_request,
    output wire [FLOOR_WIDTH-1:0]   dbg_target_request,
    output wire                     dbg_request_available,
    output wire                     dbg_direction
);

    reg [1:0] state, next_state;
    reg [FLOOR_WIDTH-1:0] current_floor;
    reg [NUM_FLOOR-1:0]   pending_request;
    reg [2:0]             counter;
    reg                   direction; // 0 = UP, 1 = DOWN

    localparam IDLE       = 2'b00;
    localparam up_state   = 2'b01;
    localparam down_state = 2'b10;
    localparam open_door  = 2'b11;

    localparam MOVE_DELAY = 2;
    localparam DOOR_DELAY = 3;

    wire [FLOOR_WIDTH-1:0] target_request;
    wire                   request_available;

    assign dbg_state              = state;
    assign dbg_current_floor      = current_floor;
    assign dbg_pending_request    = pending_request;
    assign dbg_target_request     = target_request;
    assign dbg_request_available  = request_available;
    assign dbg_direction          = direction;

    scheduler #(
        .NUM_FLOOR   (NUM_FLOOR),
        .FLOOR_WIDTH (FLOOR_WIDTH)
    ) SCH (
        .current_floor     (current_floor),
        .direction         (direction),
        .pending_request   (pending_request),
        .target_request    (target_request),
        .request_available (request_available)
    );

    // ----------------------------------------------------------------
    // Direction latch: remembers which way we were last moving,
    // used by the scheduler to decide search order (SCAN algorithm)
    // ----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            direction <= 1'b0;
        else if (state == up_state)
            direction <= 1'b0;
        else if (state == down_state)
            direction <= 1'b1;
    end

    // ----------------------------------------------------------------
    // Main sequential logic
    // ----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            current_floor   <= 0;
            pending_request <= {NUM_FLOOR{1'b0}};
            counter         <= 0;
        end
        else if (!emergency) begin
            state <= next_state;

            // --- Request bit management (independent, not mutually exclusive) ---
            if (state == open_door && counter == DOOR_DELAY)
                pending_request[current_floor] <= 1'b0;

            // NOTE: current-floor presses are intentionally allowed here too.
            // If a passenger presses the button for the floor the elevator is
            // already on (while IDLE), this lets the scheduler see it as a
            // valid request and open the door, instead of silently doing
            // nothing forever.
            if (target_floor < NUM_FLOOR)
                pending_request[target_floor] <= 1'b1;

            // --- Movement / counter management ---
            if (state == up_state && target_request != current_floor) begin
                if (counter == MOVE_DELAY) begin
                    counter <= 0;
                    if (current_floor < NUM_FLOOR-1)
                        current_floor <= current_floor + 1'b1;
                end
                else begin
                    counter <= counter + 1'b1;
                end
            end
            else if (state == down_state && target_request != current_floor) begin
                if (counter == MOVE_DELAY) begin
                    counter <= 0;
                    if (current_floor > 0)
                        current_floor <= current_floor - 1'b1;
                end
                else begin
                    counter <= counter + 1'b1;
                end
            end
            else if (state == open_door) begin
                if (counter == DOOR_DELAY)
                    counter <= 0;
                else
                    counter <= counter + 1'b1;
            end
            else begin
                counter <= 0;
            end
        end
    end

    // ----------------------------------------------------------------
    // Next-state logic
    // ----------------------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (request_available) begin
                    if (target_request > current_floor)
                        next_state = up_state;
                    else if (target_request < current_floor)
                        next_state = down_state;
                    else
                        next_state = open_door;
                end
            end

            up_state: begin
                if (target_request == current_floor)
                    next_state = open_door;
                else
                    next_state = up_state;
            end

            down_state: begin
                if (target_request == current_floor)
                    next_state = open_door;
                else
                    next_state = down_state;
            end

            open_door: begin
                if (counter == DOOR_DELAY)
                    next_state = IDLE;
                else
                    next_state = open_door;
            end

            default: next_state = IDLE;
        endcase
    end

    // ----------------------------------------------------------------
    // Output logic
    // ----------------------------------------------------------------
    always @(*) begin
        if (emergency) begin
            {move_up, move_down, door_open} = 3'b000;
        end
        else begin
            case (state)
                IDLE:       {move_up, move_down, door_open} = 3'b000;
                up_state:   {move_up, move_down, door_open} = 3'b100;
                down_state: {move_up, move_down, door_open} = 3'b010;
                open_door:  {move_up, move_down, door_open} = 3'b001;
                default:    {move_up, move_down, door_open} = 3'b000;
            endcase
        end
    end

endmodule

