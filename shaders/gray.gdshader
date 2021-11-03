shader_type canvas_item;

uniform bool grayscale = false;


void fragment() {
	
    COLOR = texture(TEXTURE, UV);
	if (grayscale){
	    float avg = (COLOR.r + COLOR.g + COLOR.b) / 3.0;
    	COLOR.rgb = vec3(avg);
	}
}	

