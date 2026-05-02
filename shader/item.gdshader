shader_type canvas_item;

// 从脚本传入，避免 GPU 重算
instance uniform vec2 rect_size = vec2(100.0, 100.0);
instance uniform float grid_size = 50.0;
instance uniform float total_len = 400.0; // 周长：(w+h)*2
instance uniform float inv_total_len = 0.0025; // 周长的倒数：1.0/total_len

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float line_thickness_ratio = 0.05;
uniform float speed = 500.0;
uniform float dash_length = 50.0;

// 圆环参数
uniform float loading_scale_factor = 0.4;
uniform float loading_speed = 3.0;
uniform float ring_arc_length = 0.75;

void fragment() {
    // 1. 精度设为低精度 (lowp/mediump)，对这种 UI 效果绰绰有余
    mediump vec2 p = UV * rect_size;
    mediump vec2 center = rect_size * 0.5;
    mediump float m = grid_size * line_thickness_ratio;

// --- 1. 边缘遮罩 ---
    mediump vec2 d_edge = min(p, rect_size - p);
    float min_edge_dist = min(d_edge.x, d_edge.y);
    // 只有在 [0, m] 范围内的像素 border_mask 才为 1.0
    float border_mask = step(0.0, min_edge_dist) - step(m, min_edge_dist);

    // --- 2. 路径长度 t 的计算 (无 if) ---
    float is_top = step(p.y, m);
    float is_right = step(rect_size.x - m, p.x) * (1.0 - is_top);
    float is_bottom = step(rect_size.y - m, p.y) * (1.0 - is_top) * (1.0 - is_right);
    // 剩下即为 left
    float is_left = 1.0 - is_top - is_right - is_bottom;

    float t = is_top * p.x
            + is_right * (rect_size.x + p.y)
            + is_bottom * (rect_size.x + rect_size.y + (rect_size.x - p.x))
            + is_left * (total_len - p.y);

    // --- 3. 双线中心对称动画 ---
    float time_base = - TIME * speed;

    // 线条1 的头部位置
    float head1 = fract(time_base * inv_total_len) * total_len;
    // 线条2 的头部位置 (偏移半个周长实现中心对称)
    float head2 = fract((time_base + total_len * 0.5) * inv_total_len) * total_len;

    // 计算像素点 t 到两个头部的距离
    float dist1 = mod(t - head1 + total_len, total_len);
    float dist2 = mod(t - head2 + total_len, total_len);

    // 计算两条线的渐变
    float dash1 = clamp(1.0 - (dist1 / dash_length), 0.0, 1.0);
    float dash2 = clamp(1.0 - (dist2 / dash_length), 0.0, 1.0);

    // 合并双线并应用平方渐变 (代替 pow)
    float border_dash = max(dash1, dash2);
    border_dash *= border_dash;

    // 最终边框贡献：只有在边缘区域才显示动画
    float final_border = border_mask * border_dash;

    // --- 中心圆环极致优化版 ---

    // 1. 半径与厚度计算 (厚度设为半径的 10%，可自行调整比例)
    float radius = min(min(rect_size.x, rect_size.y) * loading_scale_factor, grid_size * 0.3);
    float half_thickness = radius * 0.1; // 这里的 0.05 决定了圆环的总厚度是半径的 10%

    // 2. 距离计算
    vec2 to_center = p - (rect_size * 0.5);
    float dist_to_center = length(to_center);

    // 3. 距离遮罩 (无 if 版)
    // abs(dist - radius) 得到像素点到圆环中心线的距离
    // 如果这个距离小于 half_thickness，step 就会返回 1.0
    // 2. 将原来的 step 替换为线性插值
    // 原理：计算距离差，并除以平滑宽度，得到 0 到 1 之间的连续值
    float ring_dist_mask = clamp(half_thickness - abs(dist_to_center - radius), 0.0, 1.0);

    // 4. 角度遮罩 (只有在 ring_dist_mask 为 1 时计算才有意义，但为了无 if 我们全算)
    // 使用预计算的常数 0.15915 (1/2pi)
    float angle = atan(to_center.y, to_center.x);
    float rotated_angle_norm = fract((angle + 3.14159) * 0.15915 + TIME * loading_speed * 0.2);
    float arc_mask = step(rotated_angle_norm, ring_arc_length);

    // 5. 组合
    float loading_final = ring_dist_mask * arc_mask;

    COLOR = line_color;
    COLOR.a *= max(border_mask * border_dash, loading_final);
}