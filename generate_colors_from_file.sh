#!/bin/bash

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "❌ Please provide an input file."
    echo "Usage: $0 <colors-file>"
    echo "Example: $0 colors.txt"
    echo ""
    echo "Create a colors.txt file with lines like:"
    echo "primaryColor #3366CC #6699FF"
    echo "secondaryColor #CC4D33 #FF8066"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Input file '$INPUT_FILE' not found."
    echo "Create a colors.txt file with lines like:"
    echo "primaryColor #3366CC #6699FF"
    echo "secondaryColor #CC4D33 #FF8066"
    exit 1
fi

# Create the main directory
mkdir -p Colors.xcassets

echo "🎨 Color Asset Generator (File Mode)"
echo "===================================="

# Function to convert hex to RGB components
hex_to_rgb() {
    local hex=$1
    # Remove # if present
    hex="${hex#"#"}"
    # Convert to RGB (handle both 3-digit and 6-digit hex)
    if [ ${#hex} -eq 3 ]; then
        r=$((0x${hex:0:1}${hex:0:1}))
        g=$((0x${hex:1:1}${hex:1:1}))
        b=$((0x${hex:2:1}${hex:2:1}))
    else
        r=$((0x${hex:0:2}))
        g=$((0x${hex:2:2}))
        b=$((0x${hex:4:2}))
    fi
    # Convert to decimal 0-1 with 3 decimal places
    printf "%.3f %.3f %.3f" $(echo "scale=3; $r/255" | bc) $(echo "scale=3; $g/255" | bc) $(echo "scale=3; $b/255" | bc)
}

# Function to validate hex color
validate_hex() {
    local hex=$1
    if [[ $hex =~ ^#?[0-9A-Fa-f]{3}$ ]] || [[ $hex =~ ^#?[0-9A-Fa-f]{6}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Array to store color data
declare -a colors_array

echo "📖 Reading colors from $INPUT_FILE"

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    
    # Parse input
    read -r name light_hex dark_hex <<< "$line"
    
    # Validate input
    if [[ -z "$name" || -z "$light_hex" || -z "$dark_hex" ]]; then
        echo "❌ Invalid format: $line"
        echo "   Use: name light_hex dark_hex"
        continue
    fi
    
    if ! validate_hex "$light_hex"; then
        echo "❌ Invalid light hex color: $light_hex"
        continue
    fi
    
    if ! validate_hex "$dark_hex"; then
        echo "❌ Invalid dark hex color: $dark_hex"
        continue
    fi
    
    colors_array+=("$name:$light_hex:$dark_hex")
    echo "✅ Added $name: light=$light_hex dark=$dark_hex"
done < "$INPUT_FILE"

# Check if we have any colors
if [ ${#colors_array[@]} -eq 0 ]; then
    echo "❌ No valid colors found in '$INPUT_FILE'. Exiting."
    exit 1
fi

echo ""
echo "🔄 Generating ${#colors_array[@]} color sets..."

# Process each color
for color_entry in "${colors_array[@]}"; do
    # Split the entry
    IFS=':' read -r name light_hex dark_hex <<< "$color_entry"
    
    # Convert hex to RGB
    light_rgb=$(hex_to_rgb "$light_hex")
    dark_rgb=$(hex_to_rgb "$dark_hex")
    
    # Split RGB values
    IFS=' ' read -r light_r light_g light_b <<< "$light_rgb"
    IFS=' ' read -r dark_r dark_g dark_b <<< "$dark_rgb"
    
    # Create color set directory
    color_set_dir="Colors.xcassets/${name}.colorset"
    mkdir -p "$color_set_dir"
    
    # Create Contents.json
    cat > "$color_set_dir/Contents.json" << EOF
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "$light_r",
          "green": "$light_g",
          "blue": "$light_b",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "$dark_r",
          "green": "$dark_g",
          "blue": "$dark_b",
          "alpha": "1.000"
        }
      },
      "idiom": "universal",
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ]
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF
    
    echo "✅ Generated $name.colorset"
done

echo ""
echo "🎉 Successfully generated ${#colors_array[@]} color sets!"
echo "📁 Location: Colors.xcassets/"
echo ""
echo "To use in your Xcode project:"
echo "1. Drag Colors.xcassets into your Xcode project"
echo "2. Select 'Copy items if needed' and your target"
echo "3. Use in code: Color(\"colorName\") or UIColor(named: \"colorName\")"