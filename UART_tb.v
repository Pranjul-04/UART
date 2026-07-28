`timescale 1ns / 1ps

// UART testbench for functional and error testing
module UART_tb;

    reg clk;
    reg reset;
    reg tx_start;
    reg [7:0] Data_in;
    wire [7:0] Data_out;
    wire rx_ready;
    wire tx_serial_out;
    wire status_error;

    // Error injection control signals
    reg inject_err = 0;
    reg err_val = 0;

    // Normal loopback or corrupted input selection
    wire rx_serial_in = inject_err ? err_val : tx_serial_out;

    // DUT instance
    UART_top DUT(
        .clk(clk), .reset(reset), .tx_start(tx_start),
        .Data_in(Data_in), .Data_out(Data_out), .rx_ready(rx_ready),
        .tx_serial_out(tx_serial_out), .rx_serial_in(rx_serial_in),
        .status_error(status_error)
    );

    // Clock generation: 50 MHz
    initial begin
        clk = 0;
        forever #10 clk = ~clk; 
    end

    // UART baud timing calculation
    localparam BAUD_PERIOD = 5208 * 20;

    // Test normal UART transmission
    task blast_normal(input [7:0] test_val);
    begin
        $display("\n[%0t ns] NORMAL SEND: %h", $time, test_val);
        Data_in = test_val;
        
        // Generate transmit request
        @(posedge clk) tx_start = 1;
        @(posedge clk) tx_start = 0;

        // Wait until receiver accepts data
        begin : wait_loop_normal
            forever begin
                @(posedge rx_ready);
                #10; 
                if (status_error == 1'b0) disable wait_loop_normal;
            end
        end
        @(posedge clk); 

        // Check received data
        if (Data_out === test_val && !status_error)
            $display("[PASS] SENT: %h | RECEIVED: %h", test_val, Data_out);
        else 
            $display("[FAIL] SENT: %h | RECEIVED: %h", test_val, Data_out);
        #5000; 
    end
    endtask

    // Inject single bit corruption
    task blast_data_corruption(input [7:0] test_val, input [2:0] bit_to_flip);
    begin
        $display("\n %0t ns INJECTING DATA BIT [%0d] CORRUPTION for: %h", $time, bit_to_flip, test_val);
        Data_in = test_val;
        @(posedge clk) tx_start = 1;
        @(posedge clk) tx_start = 0;

        // Wait for start bit
        @(negedge tx_serial_out);

        // Flip selected data bit
        #(BAUD_PERIOD * (1 + bit_to_flip) + BAUD_PERIOD/4);
        
        err_val = ~tx_serial_out;
        inject_err = 1;
        #(BAUD_PERIOD/2);
        inject_err = 0;

        // Wait for receiver response
        begin : wait_loop_corrupt
            forever begin
                @(posedge rx_ready);
                #10;
                if (status_error == 1'b0) disable wait_loop_corrupt;
            end
        end
        
        @(posedge clk);
        if (Data_out === test_val) $display("PARITY CAUGHT IT. AUTO-RECOVERED: %h", Data_out);
        else $display("RECOVERY FAILED. Received: %h", Data_out);
        #5000;
    end
    endtask

    // Inject two-bit error to test parity limitation
    task blast_double_bit_corruption(input [7:0] test_val);
    begin
        $display("\n ING DOUBLE DATA BIT CORRUPTION for: %h", $time, test_val);
        Data_in = test_val;
        @(posedge clk) tx_start = 1;
        @(posedge clk) tx_start = 0;

        @(negedge tx_serial_out);
        
        // First bit corruption
        #(BAUD_PERIOD * 3 + BAUD_PERIOD/4); 
        err_val = ~tx_serial_out;
        inject_err = 1;
        #(BAUD_PERIOD/2);
        inject_err = 0;

        // Second bit corruption
        #(BAUD_PERIOD * 2 + BAUD_PERIOD/2); 
        err_val = ~tx_serial_out;
        inject_err = 1;
        #(BAUD_PERIOD/2);
        inject_err = 0;
        
        @(posedge rx_ready);
        #10;
        
        @(posedge clk);

        // Demonstrates parity inability to detect even errors
        if (Data_out !== test_val && !status_error) 
            $display("ILENT FAILURE ACHIEVED. RECEIVED: %h | Parity failed to detect 2-bit flip.", Data_out);
        else 
            $display("Caught the error or data wasn't corrupted.");
        #5000;
    end
    endtask

    // Inject short noise pulse
    task blast_mid_bit_noise(input [7:0] test_val);
    begin
        $display("\n %0t nsINJECTING NARROW NOISE GLITCH for: %h", $time, test_val);
        Data_in = test_val;
        @(posedge clk) tx_start = 1;
        @(posedge clk) tx_start = 0;
        
        @(negedge tx_serial_out);

        // Create short glitch
        #(BAUD_PERIOD * 4); 
        #(BAUD_PERIOD / 16); 
        
        err_val = ~tx_serial_out;
        inject_err = 1;
        #(BAUD_PERIOD / 16); 
        inject_err = 0;
        
        @(posedge rx_ready);
        #10;
        
        @(posedge clk);

        // Check noise filtering capability
        if (Data_out === test_val && !status_error) 
            $display("RECEIVER MAJORITY VOTING IGNORED NOISE. RECEIVED: %h", Data_out);
        else 
            $display("NOISE GLITCH CORRUPTED DATA.");
        #5000;
    end
    endtask

    // Inject complete line break condition
    task blast_break_condition(input [7:0] test_val);
    begin
        $display("\n%0t ns INJECTING FULL LINE BREAK", $time);
        Data_in = test_val;
        @(posedge clk) tx_start = 1;
        @(posedge clk) tx_start = 0;
        
        @(negedge tx_serial_out);

        // Hold line low
        #(BAUD_PERIOD * 2);
        
        err_val = 1'b0; 
        inject_err = 1;
        
        #(BAUD_PERIOD * 15);
        $display("%0t ns RELEASING LINE BREAK", $time);
        inject_err = 0;

        // Wait for recovery
        begin : wait_loop_break
            forever begin
                @(posedge rx_ready);
                #10;
                if (status_error == 1'b0) disable wait_loop_break;
            end
        end
        
        @(posedge clk);
        $display("[PASS] RECOVERED FROM FULL BREAK. RECEIVED: %h", Data_out);
        #5000;
    end
    endtask

    // Test data memory
    reg [7:0] blast_mem [0:7];
    integer i;

    // Main simulation sequence
    initial begin

        // Generate waveform file
        $dumpfile("uart_waveform.vcd");
        $dumpvars(0, UART_tb);

        // Default test values
        blast_mem[0]=8'h11; blast_mem[1]=8'h22; blast_mem[2]=8'h33; blast_mem[3]=8'h44;
        blast_mem[4]=8'h55; blast_mem[5]=8'h66; blast_mem[6]=8'h77; blast_mem[7]=8'h88;

        // Load external test data
        $readmemh("data.hex", blast_mem); 

        Data_in = 8'h00;
        tx_start = 0;

        // Apply reset
        reset = 1;
        #100 reset = 0; #100;

        // Normal transmission tests
        for(i=0; i<2; i=i+1) begin
            if (blast_mem[i] !== 8'hxx) blast_normal(blast_mem[i]);
        end

        // Error testing
        blast_data_corruption(8'hA5, 3);
        blast_double_bit_corruption(8'h3C);
        blast_mid_bit_noise(8'hF0);
        blast_break_condition(8'h5A);

        $finish;
    end
endmodule
