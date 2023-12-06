package engine

UI_Size_Kind :: enum {
    Null,
    Pixels,
    TextContent,
    PercentOfParent,
    ChildrenSum,
}

UI_Axis2 :: enum {
  X,
  Y,
}

UI_Size :: struct {
  kind:       UI_Size_Kind,
  value:      f32,
  strictness: f32,
}

UI_Widget :: struct {
    semantic_size:         [len(UI_Axis2)]UI_Size,
    // Recomputed every frame
    computed_rel_position: [len(UI_Axis2)]f32,
    computed_size:         [len(UI_Axis2)]f32,
    rect:                  Vector4f32,
}
