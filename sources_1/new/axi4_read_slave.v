module axi4_read_slave(

    // --------------------------------
    // Clock and reset
    // --------------------------------

    input wire clk,
    input wire rst_n,

    // --------------------------------
    // AXI4 Read Address Channel (AR)
    // --------------------------------

    input wire [31:0] s_axi_araddr,
    input wire [7:0]  s_axi_arlen,
    input wire [2:0]  s_axi_arsize,
    input wire [1:0]  s_axi_arburst,
    input wire        s_axi_arvalid,
    output wire       s_axi_arready,

    // --------------------------------
    // AXI4 Read Data Channel (R)
    // --------------------------------

    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output wire        s_axi_rvalid,
    input wire         s_axi_rready,

    // --------------------------------
    // SRAM Controller Interface
    // --------------------------------

    output wire        sram_req,
    output wire        sram_we,
    output wire [7:0]  sram_addr,

    input wire         sram_ready,
    input wire         sram_done,
    input wire [31:0]  sram_rdata

);

    // --------------------------------
    // FSM State Encoding
    // --------------------------------

    localparam IDLE       = 3'b000;
    localparam SRAM_ISSUE = 3'b001;
    localparam SRAM_WAIT  = 3'b010;
    localparam READ_DATA  = 3'b011;

    reg [2:0] state;


    // --------------------------------
    // Internal Registers
    // --------------------------------

    reg [31:0] current_addr;
    reg [4:0] beats_remaining;

    reg [31:0] read_data_reg;


    // --------------------------------
    // AXI Output Logic
    // --------------------------------

    assign s_axi_arready = (state == IDLE);

    assign s_axi_rvalid = (state == READ_DATA);

    assign s_axi_rdata = read_data_reg;

    // OKAY response
    assign s_axi_rresp = 2'b00;

    // Assert RLAST for the final beat
    assign s_axi_rlast =
        (state == READ_DATA) &&
        (beats_remaining == 5'd1);


    // --------------------------------
    // SRAM Interface
    // --------------------------------

    assign sram_req = (state == SRAM_ISSUE);

    // Read operation
    assign sram_we = 1'b0;

    // Convert byte address to word address
    assign sram_addr = current_addr[9:2];


    // --------------------------------
    // Main Sequential Logic
    // --------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state           <= IDLE;

            current_addr    <= 32'd0;
            beats_remaining <= 5'd0;

            read_data_reg   <= 32'd0;

        end

        else begin

            case (state)

                // ------------------------
                // IDLE: Accept read address
                // ------------------------

                IDLE: begin

                    if (s_axi_arvalid && s_axi_arready) begin

                        current_addr <= s_axi_araddr;

                        // ARLEN = number of beats - 1
                        beats_remaining <=
                            {1'b0, s_axi_arlen[3:0]} + 5'd1;

                        state <= SRAM_ISSUE;

                    end

                end


                // ------------------------
                // Issue SRAM read request
                // ------------------------

                SRAM_ISSUE: begin

                    if (sram_ready) begin

                        state <= SRAM_WAIT;

                    end

                end


                // ------------------------
                // Wait for SRAM response
                // ------------------------

                SRAM_WAIT: begin

                    if (sram_done) begin

                        read_data_reg <= sram_rdata;

                        state <= READ_DATA;

                    end

                end


                // ------------------------
                // Send AXI read data
                // ------------------------

                READ_DATA: begin

                    if (s_axi_rvalid && s_axi_rready) begin

                        if (beats_remaining == 5'd1) begin

                            // Final beat completed
                            state <= IDLE;

                        end

                        else begin

                            beats_remaining <=
                                beats_remaining - 5'd1;

                            // Next 32-bit word
                            current_addr <= current_addr + 32'd4;

                            state <= SRAM_ISSUE;

                        end

                    end

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule
