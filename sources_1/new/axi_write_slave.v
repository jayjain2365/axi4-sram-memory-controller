
module axi4_write_slave (

    // --------------------------------
    // Clock and reset
    // --------------------------------

    input wire clk,
    input wire rst_n,

    // --------------------------------
    // AXI4 Write Address Channel (AW)
    // --------------------------------

    input wire [31:0] s_axi_awaddr,
    input wire [7:0]  s_axi_awlen,
    input wire [2:0]  s_axi_awsize,
    input wire [1:0]  s_axi_awburst,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,

    // --------------------------------
    // AXI4 Write Data Channel (W)
    // --------------------------------

    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire        s_axi_wlast,
    input wire        s_axi_wvalid,
    output wire       s_axi_wready,

    // --------------------------------
    // AXI4 Write Response Channel (B)
    // --------------------------------

    output wire [1:0] s_axi_bresp,
    output wire       s_axi_bvalid,
    input wire        s_axi_bready,

    // --------------------------------
    // SRAM Controller Interface
    // --------------------------------

    output wire       sram_req,
    output wire       sram_we,
    output wire [7:0] sram_addr,
    output wire [31:0] sram_wdata,
    output wire [3:0] sram_be,

    input wire        sram_ready,
    input wire        sram_done

);

    // --------------------------------
    // FSM State Encoding
    // --------------------------------

    localparam IDLE       = 3'b000;
    localparam WRITE_DATA = 3'b001;
    localparam SRAM_ISSUE = 3'b010;
    localparam SRAM_WAIT  = 3'b011;
    localparam WRITE_RESP = 3'b100;

    reg [2:0] state;

    // --------------------------------
    // Internal Registers
    // --------------------------------

    reg [31:0] current_addr;
    reg [4:0]  beats_remaining;

    reg [31:0] write_data_reg;
    reg [3:0]  write_strb_reg;

    reg write_error;

    // --------------------------------
    // AXI Output Logic
    // --------------------------------

    assign s_axi_awready = (state == IDLE);

    assign s_axi_wready = (state == WRITE_DATA);

    assign s_axi_bvalid = (state == WRITE_RESP);

    // OKAY = 00
    // SLVERR = 10
    assign s_axi_bresp = write_error ? 2'b10 : 2'b00;

    // --------------------------------
    // SRAM Interface
    // --------------------------------

    assign sram_req   = (state == SRAM_ISSUE);
    assign sram_we    = 1'b1;

    assign sram_addr  = current_addr[9:2];
    assign sram_wdata = write_data_reg;
    assign sram_be    = write_strb_reg;


    // --------------------------------
    // Main Sequential Logic
    // --------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state           <= IDLE;

            current_addr    <= 32'd0;
            beats_remaining <= 5'd0;

            write_data_reg  <= 32'd0;
            write_strb_reg  <= 4'd0;

            write_error     <= 1'b0;

        end

        else begin

            case (state)

                // ------------------------
                // IDLE: Accept write address
                // ------------------------

                IDLE: begin

                    if (s_axi_awvalid && s_axi_awready) begin

                        current_addr <= s_axi_awaddr;

                        // AXI AWLEN = number of beats - 1
                        beats_remaining <=
                            {1'b0, s_axi_awlen[3:0]} + 5'd1;

                        write_error <= 1'b0;

                        state <= WRITE_DATA;

                    end

                end


                // ------------------------
                // Accept one write data beat
                // ------------------------

                WRITE_DATA: begin

                    if (s_axi_wvalid && s_axi_wready) begin

                        write_data_reg <= s_axi_wdata;
                        write_strb_reg <= s_axi_wstrb;

                        // Check WLAST against expected final beat
                        if (s_axi_wlast !=
                            (beats_remaining == 5'd1)) begin

                            write_error <= 1'b1;

                        end

                        state <= SRAM_ISSUE;

                    end

                end


                // ------------------------
                // Issue request to SRAM
                // ------------------------

                SRAM_ISSUE: begin

                    if (sram_ready) begin

                        state <= SRAM_WAIT;

                    end

                end


                // ------------------------
                // Wait for SRAM completion
                // ------------------------

                SRAM_WAIT: begin

                    if (sram_done) begin

                        if (beats_remaining == 5'd1) begin

                            state <= WRITE_RESP;

                        end

                        else begin

                            beats_remaining <=
                                beats_remaining - 5'd1;

                            // Next 32-bit word
                            current_addr <= current_addr + 32'd4;

                            state <= WRITE_DATA;

                        end

                    end

                end


                // ------------------------
                // Send AXI write response
                // ------------------------

                WRITE_RESP: begin

                    if (s_axi_bready && s_axi_bvalid) begin

                        state <= IDLE;

                    end

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule
