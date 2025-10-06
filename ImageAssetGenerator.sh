#!/bin/bash

# Check if input directory is provided
if [ $# -eq 0 ]; then
    echo "❌ Please provide an input directory with images."
    echo "Usage: $0 <input-directory>"
    echo "Example: $0 ./images"
    echo ""
    echo "Supported formats:"
    echo "- PDF: ImageName.pdf"
    echo "- PNG: ImageName.png, ImageName@2x.png, ImageName@3x.png"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="Assets.xcassets"

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Input directory '$INPUT_DIR' not found."
    exit 1
fi

# Create the main directory
mkdir -p "$OUTPUT_DIR"

echo "🎨 Image Asset Generator"
echo "========================"
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Array to store image data
declare -a images_array

# Function to get base name without extension or scale suffix
get_base_name() {
    local filename=$(basename "$1")
    # Remove extension
    filename="${filename%.*}"
    # Remove scale suffixes (@2x, @3x)
    filename="${filename%@2x}"
    filename="${filename%@3x}"
    echo "$filename"
}

# Function to detect image type and scales
detect_image_type() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    local basename=$(get_base_name "$file")
    
    # Check if it's a PDF
    if [[ "$extension" == "pdf" ]]; then
        echo "pdf:$basename"
        return
    fi
    
    # Check for scale suffixes (@2x, @3x)
    if [[ "$filename" =~ @2x\. ]]; then
        echo "png_2x:$basename"
    elif [[ "$filename" =~ @3x\. ]]; then
        echo "png_3x:$basename"
    else
        # Check if there's a base PNG (without scale suffix)
        local base_png="${basename}.png"
        if [[ "$filename" == "$base_png" ]]; then
            echo "png_1x:$basename"
        else
            echo "unknown:$basename"
        fi
    fi
}

# Scan input directory
echo "📁 Scanning input directory..."

# Process PDF files
for pdf_file in "$INPUT_DIR"/*.pdf; do
    if [ -f "$pdf_file" ]; then
        basename=$(get_base_name "$pdf_file")
        images_array+=("pdf:$basename:$pdf_file")
        echo "✅ Found PDF: $basename.pdf"
    fi
done

# Process PNG files and group by base name
declare -A png_files

for png_file in "$INPUT_DIR"/*.png; do
    if [ -f "$png_file" ]; then
        basename=$(get_base_name "$png_file")
        filename=$(basename "$png_file")
        
        # Detect scale
        if [[ "$filename" =~ @2x\. ]]; then
            png_files["${basename}_2x"]="$png_file"
            echo "✅ Found PNG: $basename@2x.png"
        elif [[ "$filename" =~ @3x\. ]]; then
            png_files["${basename}_3x"]="$png_file"
            echo "✅ Found PNG: $basename@3x.png"
        else
            # Base PNG (1x)
            png_files["${basename}_1x"]="$png_file"
            echo "✅ Found PNG: $basename.png (1x)"
        fi
    fi
done

# Group PNG files by base name and check for complete sets
declare -A png_groups
for key in "${!png_files[@]}"; do
    basename="${key%_*}"
    scale="${key##*_}"
    png_groups["$basename"]+="$scale:${png_files[$key]} "
done

# Add PNG groups to images array
for basename in "${!png_groups[@]}"; do
    images_array+=("png:$basename:${png_groups[$basename]}")
    
    # Check which scales we have
    scales=""
    if [[ "${png_groups[$basename]}" =~ 1x ]]; then scales+="1x "; fi
    if [[ "${png_groups[$basename]}" =~ 2x ]]; then scales+="2x "; fi
    if [[ "${png_groups[$basename]}" =~ 3x ]]; then scales+="3x "; fi
    
    echo "📦 PNG Group: $basename (scales: $scales)"
done

# Check if we have any images
if [ ${#images_array[@]} -eq 0 ]; then
    echo "❌ No images found in '$INPUT_DIR'. Supported formats: PDF, PNG"
    exit 1
fi

echo ""
echo "🔄 Generating ${#images_array[@]} image sets..."

# Process each image
for image_entry in "${images_array[@]}"; do
    # Split the entry
    IFS=':' read -r type name paths <<< "$image_entry"
    
    # Create image set directory
    image_set_dir="$OUTPUT_DIR/${name}.imageset"
    mkdir -p "$image_set_dir"
    
    if [ "$type" == "pdf" ]; then
        # Handle PDF files
        cp "$paths" "$image_set_dir/${name}.pdf"
        
        # Create Contents.json for PDF
        cat > "$image_set_dir/Contents.json" << EOF
{
  "images": [
    {
      "filename": "${name}.pdf",
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  },
  "properties": {
    "preserves-vector-representation": true
  }
}
EOF
        echo "✅ Generated $name.imageset (PDF)"
        
    else
        # Handle PNG files
        IFS=' ' read -ra scale_files <<< "$paths"
        declare -A scales_map
        
        # Parse scale files
        for scale_file in "${scale_files[@]}"; do
            IFS=':' read -r scale filepath <<< "$scale_file"
            scales_map["$scale"]="$filepath"
        done
        
        # Copy files and build images array for JSON
        json_images=""
        first=true
        
        # Process 1x scale
        if [ -n "${scales_map[1x]}" ]; then
            cp "${scales_map[1x]}" "$image_set_dir/${name}.png"
            if [ "$first" = true ]; then
                first=false
            else
                json_images="$json_images,"
            fi
            json_images="$json_images
    {
      \"idiom\": \"universal\",
      \"filename\": \"${name}.png\",
      \"scale\": \"1x\"
    }"
        fi
        
        # Process 2x scale
        if [ -n "${scales_map[2x]}" ]; then
            cp "${scales_map[2x]}" "$image_set_dir/${name}@2x.png"
            if [ "$first" = true ]; then
                first=false
            else
                json_images="$json_images,"
            fi
            json_images="$json_images
    {
      \"idiom\": \"universal\",
      \"filename\": \"${name}@2x.png\",
      \"scale\": \"2x\"
    }"
        fi
        
        # Process 3x scale
        if [ -n "${scales_map[3x]}" ]; then
            cp "${scales_map[3x]}" "$image_set_dir/${name}@3x.png"
            if [ "$first" = true ]; then
                first=false
            else
                json_images="$json_images,"
            fi
            json_images="$json_images
    {
      \"idiom\": \"universal\",
      \"filename\": \"${name}@3x.png\",
      \"scale\": \"3x\"
    }"
        fi
        
        # Create Contents.json for PNG
        cat > "$image_set_dir/Contents.json" << EOF
{
  "images": [${json_images}
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF
        
        # Show which scales were generated
        scales_generated=""
        if [ -n "${scales_map[1x]}" ]; then scales_generated+="1x "; fi
        if [ -n "${scales_map[2x]}" ]; then scales_generated+="2x "; fi
        if [ -n "${scales_map[3x]}" ]; then scales_generated+="3x "; fi
        
        echo "✅ Generated $name.imageset (PNG - scales: $scales_generated)"
    fi
done

echo ""
echo "🎉 Successfully generated ${#images_array[@]} image sets!"
echo "📁 Location: $OUTPUT_DIR/"
echo ""
echo "To use in your Xcode project:"
echo "1. Drag $OUTPUT_DIR into your Xcode project"
echo "2. Select 'Copy items if needed' and your target"
echo "3. Use in code: Image(\"imageName\") or UIImage(named: \"imageName\")"