extends SceneTree

func _init():
    var scene = load("res://test_level.tscn").instantiate()
    var tm = scene.get_node("Tilemap/TileMapLayer")
    if not tm:
        print("No TileMapLayer")
        quit()
        return

    var used_cells = tm.get_used_cells()
    print("Used cells count: ", used_cells.size())
    
    var raw_polys = []
    
    for cell in used_cells:
        var tile_data = tm.get_cell_tile_data(cell)
        if tile_data == null: continue
        
        # We need to know physics_layers count but assume 1 (index 0)
        var poly_count = 0
        if tm.tile_set and tm.tile_set.get_physics_layers_count() > 0:
            poly_count = tile_data.get_collision_polygons_count(0)
            
        for i in range(poly_count):
            var poly = tile_data.get_collision_polygon_points(0, i)
            var cell_pos_local = tm.map_to_local(cell)
            var global_poly = PackedVector2Array()
            for pt in poly:
                global_poly.append(tm.to_global(cell_pos_local + pt))
            raw_polys.append(global_poly)
            
    print("Raw polygons count: ", raw_polys.size())
    
    if raw_polys.size() > 0:
        var merged = [raw_polys[0]]
        for i in range(1, raw_polys.size()):
            var p2 = raw_polys[i]
            var next_merged = []
            var combined_any = false
            for m in merged:
                var res = Geometry2D.merge_polygons(m, p2)
                if res.size() == 1:
                    pass
            # Actually writing a full merge loop in GDScript quickly is a bit complex 
            # because merging might cascade. Let us just use a single loop or print.
            
    quit()

