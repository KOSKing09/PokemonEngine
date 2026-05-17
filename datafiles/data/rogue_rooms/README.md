# Rogue Rooms

Put exported rogue interior JSON files here.

These are different from `data/rogue_prefabs`:

- `rogue_prefabs` are stamped into the infinite outdoor world.
- `rogue_rooms` are loaded into the reusable runtime room `rm_rogue_building`.

An outdoor prefab door can enter one of these rooms by using an `owarp` with:

```gml
_room = rm_rogue_building;
rogue_room_file = "small_house.json";
remember_rogue_return = true;
```

The interior exit should use:

```gml
return_to_rogue = true;
```
