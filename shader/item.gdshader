shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float line_width : hint_range(0.0, 0.2) = 0.05;
uniform vec2 rect_size = vec2(100.0, 100.0); // 由脚本传入
uniform float speed = 2.0;

void fragment() {
    vec2 uv = UV;
    // 使用像素单位计算，保证虚线在不同尺寸下比例一致
    vec2 pixel_uv = uv * rect_size;
    
    // 1. 边缘遮罩逻辑 (加入 epsilon 防止细线)
    float m = line_width * min(rect_size.x, rect_size.y);
    float border = step(0.0, pixel_uv.x) * step(0.0, pixel_uv.y) * step(pixel_uv.x, rect_size.x) * step(pixel_uv.y, rect_size.y);
    float inner = step(m, pixel_uv.x) * step(m, pixel_uv.y) * step(pixel_uv.x, rect_size.x - m) * step(pixel_uv.y, rect_size.y - m);
    float mask = border - inner;

    // 2. 环绕路径计算 (基于像素长度，虚线不会变形)
    float t = 0.0;
    float total_len = (rect_size.x + rect_size.y) * 2.0;
    
    if (pixel_uv.y < m) t = pixel_uv.x;
    else if (pixel_uv.x > rect_size.x - m) t = rect_size.x + pixel_uv.y;
    else if (pixel_uv.y > rect_size.y - m) t = rect_size.x + rect_size.y + (rect_size.x - pixel_uv.x);
    else t = total_len - pixel_uv.y;

    // 3. 虚线动画 (50.0 是虚线间的像素距离)
    float dash = step(0.5, fract((t - TIME * speed * 50.0) / 40.0));
    
    COLOR = line_color;
    COLOR.a *= mask * dash;
}