# Pooling Integration Changes

## max_avg_pooling.v

- Changed `count_element_reg`, `count_element_d`, `count_ofelement_rd_reg`, `count_ofelement_rd_d`, and `num_element_cur_pass` to 13-bit so they match the 13-bit config FIFO payload.
- Changed `complete_fifo_rd` so `complete_fifo` is read only when OFBUF accepts a valid pooling output.
- Changed the config FIFO write condition to also write on the `end_height_d` case, matching the data path condition that can write `complete_fifo` at the last height.
- Used explicit `13'd0` and `13'd1` constants for the 13-bit element counters.

## CNN_accel_tb.v

- Added the new `CNN_accel` pooling table ports: `cnn_table_is_use_pool_i`, `cnn_table_is_max_pool_i`, `cnn_table_pool_size_i`, and `cnn_table_is_stride_over_i`.
- Added per-layer pooling configuration and validation. The testbench now rejects pool stride cases except:
  - `stride_over = 1` when `pool_size == pool_stride`
  - `stride_over = 0` when `pool_size == pool_stride + 1`
- Updated expected output generation so golden data is calculated as convolution plus scale/ReLU, then optional max/average pooling.
- Updated OFBUF expected row count, output word count, and memory compare dimensions to use the post-pooling width.
- Added explicit testcases for no pooling, max pooling, average pooling, global max pooling, global average pooling, and pooling windows that leave a tail at the edge.
- Added comments beside each `run_case_pool` testcase to document the exact parameter mapping and pooling configuration used by that case.
- Added `conv_ofwidth` and `pool_ofwidth` comments for each pooling testcase.

## scale_ReLU.v

- Added `scale_comp_done_compute_i` and `scale_comp_done_compute_layer_i` inputs.
- Added `scale_ofbuf_done_compute_o` and `scale_ofbuf_done_compute_layer_o` outputs.
- Added a 10-stage pipeline for both done signals.
- The done pipeline advances with `pipe_rdy[1]` through `pipe_rdy[10]`, so each done stage uses the ready condition of the next data pipeline stage.

## computation.v

- Connected the done signals from `comp_pu` into each `scale_ReLU` lane.
- Changed the done vectors exported by `computation` to use the delayed outputs from `scale_ReLU`, so pooling receives done signals aligned with scaled data.
