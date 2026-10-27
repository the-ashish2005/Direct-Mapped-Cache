`timescale 1ns/1ps
module tb_address_decoder;
reg  [31:0] address;
    wire [21:0] tag;
    wire [5:0]  index;
    wire [3:0]  offset;
integer test_count;
    integer pass_count;
// Device Under Test (DUT)
    address_decoder dut (
        .address(address),
        .tag(tag),
        .index(index),
        .offset(offset)
    );
// Task for testing one address
    task check_address;
        input [31:0] test_address;
        input [21:0] expected_tag;
        input [5:0]  expected_index;
        input [3:0]  expected_offset;
begin
            address = test_address;
            #10;
            test_count = test_count + 1;
if (tag === expected_tag &&
                index === expected_index &&
                offset === expected_offset) begin
                pass_count = pass_count + 1;
$display(
                    "PASS | Address=%h Tag=%h Index=%d Offset=%d",
                    address, tag, index, offset
                );
end else begin
                $display("FAIL | Address=%h", address);
                $display(
                    "Expected: Tag=%h Index=%d Offset=%d",
                    expected_tag, expected_index, expected_offset
                );
                $display(
                    "Actual:   Tag=%h Index=%d Offset=%d",
                    tag, index, offset
                );
$fatal(1, "Address decoder test failed");
            end
        end
    endtask
initial begin
        // Save waveform data
        $dumpfile("results/waveforms/address_decoder.vcd");
        $dumpvars(0, tb_address_decoder);
test_count = 0;
        pass_count = 0;
        address = 0;
$display("========================================");
        $display(" ADDRESS DECODER VERIFICATION");
        $display("========================================");
// Address 0
        check_address(32'h00000000, 22'h000000, 6'd0, 4'd0);
// Last byte in block 0
        check_address(32'h0000000F, 22'h000000, 6'd0, 4'd15);
// First byte in block 1
        check_address(32'h00000010, 22'h000000, 6'd1, 4'd0);
// Cache line 4
        check_address(32'h00000040, 22'h000000, 6'd4, 4'd0);
// Memory block 64 maps back to cache line 0
        check_address(32'h00000400, 22'h000001, 6'd0, 4'd0);
// Nontrivial address
        check_address(32'h12345678, 22'h048D15, 6'd39, 4'd8);
// Maximum 32-bit address
        check_address(32'hFFFFFFFF, 22'h3FFFFF, 6'd63, 4'd15);
$display("========================================");
        $display("Tests executed : %0d", test_count);
        $display("Tests passed   : %0d", pass_count);
        $display("Tests failed   : %0d", test_count-pass_count);
        $display("========================================");
$finish;
    end
endmodule