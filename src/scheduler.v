module scheduler #(
    parameter integer NUM_FLOOR   = 5,
    parameter integer FLOOR_WIDTH = $clog2(NUM_FLOOR)
)(
    input  wire [FLOOR_WIDTH-1:0] current_floor,
    input  wire                   direction,        // 0 = UP, 1 = DOWN
    input  wire [NUM_FLOOR-1:0]   pending_request,

    output reg  [FLOOR_WIDTH-1:0] target_request,
    output reg                    request_available
);

    localparam UP   = 1'b0;
    localparam DOWN = 1'b1;

    integer i;
    integer cf;      // signed working copy of current_floor
    reg     found;

    always @(*) begin
        found             = 1'b0;
        request_available = 1'b0;
        target_request    = current_floor;
        cf                = current_floor; // safe signed copy, avoids unsigned wraparound

        if (direction == UP) begin
            // Search upward from current floor first
            for (i = cf; i < NUM_FLOOR; i = i + 1) begin
                if (!found && pending_request[i]) begin
                    target_request     = i[FLOOR_WIDTH-1:0];
                    request_available  = 1'b1;
                    found              = 1'b1;
                end
            end
            // Nothing above -> reverse and search downward
            if (!found) begin
                for (i = cf - 1; i >= 0; i = i - 1) begin
                    if (!found && pending_request[i]) begin
                        target_request    = i[FLOOR_WIDTH-1:0];
                        request_available = 1'b1;
                        found             = 1'b1;
                    end
                end
            end
        end
        else begin // direction == DOWN
            // Search downward from current floor first
            for (i = cf; i >= 0; i = i - 1) begin
                if (!found && pending_request[i]) begin
                    target_request    = i[FLOOR_WIDTH-1:0];
                    request_available = 1'b1;
                    found             = 1'b1;
                end
            end
            // Nothing below -> reverse and search upward
            if (!found) begin
                for (i = cf + 1; i < NUM_FLOOR; i = i + 1) begin
                    if (!found && pending_request[i]) begin
                        target_request    = i[FLOOR_WIDTH-1:0];
                        request_available = 1'b1;
                        found             = 1'b1;
                    end
                end
            end
        end
    end

endmodule
