# Lava System - Hybrid Approach (Option C)

A dynamic lava system combining **particle effects** with **collision zones** for optimal performance and gameplay feel.

## Architecture

### Components

1. **GPUParticles2D** - Visual lava effects
   - Emits 200 particles at a time
   - Flowing downward with gravity and spread
   - Color fades from bright orange to dark red
   - Texture-based for visual quality

2. **LavaSurface (StaticBody2D)** - Collision surface
   - Invisible rectangle below the emission point
   - Particles can collide with it visually
   - Collision layer 1 (visual only)

3. **DamageZone (Area2D)** - Gameplay collision
   - Larger invisible rectangle covering the lava area
   - Detects player/object contact
   - Emits `player_touched_lava` signal
   - Collision layer 2 (gameplay)

## Features

✓ **Dynamic visual effects** - Flowing, splashing lava particles  
✓ **Performance optimized** - No complex physics simulation  
✓ **Easy damage system** - Simple signal-based detection  
✓ **Customizable** - Adjust particle counts, colors, velocities  
✓ **Splash effects** - Can create splash particles on demand  

## Usage

### Basic Setup
```gdscript
# In your level or scene
var lava_system = preload("res://lava_system.tscn").instantiate()
add_child(lava_system)
lava_system.global_position = Vector2(300, 400)

# Connect to damage signal
lava_system.player_touched_lava.connect(func(): player.take_damage(10))
```

### Control Particle Emission
```gdscript
lava_system.set_emission_enabled(false)  # Stop emissions
lava_system.set_emission_enabled(true)   # Resume emissions
```

### Create Splash Effects
```gdscript
lava_system.create_splash(splash_position, force)
```

## Customization

- **Particle Count**: Edit `particles.amount` in `setup_particles()`
- **Flow Speed**: Adjust `initial_velocity_min/max`
- **Spread**: Modify `spread` value (0-360)
- **Color**: Change `Color(1.0, 0.3, 0.0, 0.9)` for different lava colors
- **Damage Zone Size**: Adjust `RectangleShape2D_damage` size in the scene

## Collision Layers

- Layer 1: Visual collision (particles can bounce)
- Layer 2: Damage detection (player collision)
- Adjust as needed for your game's layer configuration

## Performance Notes

- Uses GPU particles (efficient rendering)
- No ongoing physics simulation overhead
- Simple area detection only
- Scales well with multiple lava systems
