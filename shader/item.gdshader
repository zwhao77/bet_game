shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float line_thickness : hint_range(1.0, 20.0) = 4.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float speed = 1.0;
uniform float dash_ratio : hint_range(0.0, 0.5) = 0.33;
uniform float fade_hardness : hint_range(0.1, 10.0) = 1.0; // 控制渐变硬度

void fragment() {
    vec2 pixel_uv = UV * rect_size;
    float m = line_thickness;

    // --- 1. 遮罩逻辑 ---
    float border = step(0.0, pixel_uv.x) * step(0.0, pixel_uv.y) * step(pixel_uv.x, rect_size.x) * step(pixel_uv.y, rect_size.y);
    float inner = step(m, pixel_uv.x) * step(m, pixel_uv.y) * step(pixel_uv.x, rect_size.x - m) * step(pixel_uv.y, rect_size.y - m);
    float mask = border - inner;

    // --- 2. 路径计算 (修复长方形适配) ---
    float total_len = (rect_size.x + rect_size.y) * 2.0;
    float t = 0.0;

    // 关键修正：不再只用 m 判断，而是判断像素离哪条边最近，防止长边判定失效
    float dist_top = pixel_uv.y;
    float dist_bottom = rect_size.y - pixel_uv.y;
    float dist_left = pixel_uv.x;
    float dist_right = rect_size.x - pixel_uv.x;
    float min_edge_dist = min(min(dist_top, dist_bottom), min(dist_left, dist_right));

    if (min_edge_dist == dist_top) t = pixel_uv.x;
    else if (min_edge_dist == dist_right) t = rect_size.x + pixel_uv.y;
    else if (min_edge_dist == dist_bottom) t = rect_size.x + rect_size.y + (rect_size.x - pixel_uv.x);
    else t = total_len - pixel_uv.y;

    // --- 3. 动画与渐变逻辑 ---
    float progress = t / total_len;
    // 修改符号控制旋转方向，- 为顺时针，+ 为逆时针
    float offset = fract(TIME * speed * 0.2);
    float current_pos = fract(progress + offset);

    // 计算两条对称虚线的渐变 (取代原来的 step)
    // 在起点处值为 1.0，向后拉伸到 dash_ratio 处变为 0.0
    float d1 = current_pos;
    float d2 = fract(current_pos - 0.5);

    float tail1 = clamp(1.0 - (d1 / dash_ratio), 0.0, 1.0);
    float tail2 = clamp(1.0 - (d2 / dash_ratio), 0.0, 1.0);

    // 合并两条线并应用硬度曲线
    float dash = pow(max(tail1, tail2), fade_hardness);

    COLOR = line_color;
    COLOR.a *= mask * dash;
}