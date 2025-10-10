/// cam_is_valid_index(idx) -> bool   (v1.0)
function cam_is_valid_index(_idx) {
    return (is_array(view_camera))
        && (array_length(view_camera) > _idx)
        && (is_real(view_camera[_idx]))
        && (view_camera[_idx] != -1);
}
