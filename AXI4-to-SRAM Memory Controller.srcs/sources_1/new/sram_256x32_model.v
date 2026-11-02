module sram_256x32_model (
    input             clk,
    input             mem_en,
    input             mem_we,

    input      [7:0]  mem_addr,
    input      [31:0] mem_wdata,
    input      [3:0]  mem_be,

    output reg [31:0] mem_rdata
);

    // 256 words, each containing 32 bits
    reg [31:0] mem [0:255];

    integer i;

    always @(posedge clk) begin

        if (mem_en) begin

            // Write operation
            if (mem_we) begin

                if (mem_be[0])
                    mem[mem_addr][7:0] <= mem_wdata[7:0];

                if (mem_be[1])
                    mem[mem_addr][15:8] <= mem_wdata[15:8];

                if (mem_be[2])
                    mem[mem_addr][23:16] <= mem_wdata[23:16];

                if (mem_be[3])
                    mem[mem_addr][31:24] <= mem_wdata[31:24];

            end

            // Read operation
            else begin
                mem_rdata <= mem[mem_addr];
            end

        end

    end

endmodule
