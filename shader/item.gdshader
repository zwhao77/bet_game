shader_type canvas_item;

// 使用 instance uniform 实现节点独立的实时同步
instance uniform vec2 rect_size = vec2(100.0, 100.0);

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float line_thickness : hint_range(1.0, 20.0) = 2.0;
uniform float speed = 500.0;
uniform float dash_length : hint_range(10.0, 500.0) = 50.0;
uniform float fade_hardness : hint_range(0.1, 10.0) = 1.0;

// --- 中心加载图案 (开口圆环优化版) ---
uniform float loading_scale_factor : hint_range(0.1, 0.9) = 0.4;
uniform float max_loading_radius : hint_range(10.0, 200.0) = 40.0;
uniform float loading_thickness : hint_range(1.0, 10.0) = 3.0;
uniform float loading_speed = 3.0; // 降低基础速度

// 【新参数】定义圆环的弧度大小 (0.0 到 1.0)
// 0.75 表示显示 3/4 个圆（270度），缺口 90 度。
uniform float ring_arc_length : hint_range(0.1, 0.9) = 0.75;
// 【新参数】使开口边缘平滑
uniform float arc_smoothing : hint_range(0.01, 0.1) = 0.02;

void fragment() {
    vec2 p = UV * rect_size;
    vec2 center = rect_size * 0.5;
    float m = line_thickness;

    // --- 1. 边缘遮罩 (无分支版) ---
    vec2 d_edge = min(p, rect_size - p);
    float min_edge_dist = min(d_edge.x, d_edge.y);
    float border_mask = step(0.0, min_edge_dist) - step(m, min_edge_dist);

    // --- 2. 路径长度计算 (用 step 消除 if 判断哪条边) ---
    float total_len = (rect_size.x + rect_size.y) * 2.0;

    float is_top = step(p.y, m);
    float is_right = step(rect_size.x - m, p.x) * (1.0 - is_top);
    float is_bottom = step(rect_size.y - m, p.y) * (1.0 - is_top) * (1.0 - is_right);
    float is_left = (1.0 - is_top) * (1.0 - is_right) * (1.0 - is_bottom);

    float t = is_top * p.x
            + is_right * (rect_size.x + p.y)
            + is_bottom * (rect_size.x + rect_size.y + (rect_size.x - p.x))
            + is_left * (total_len - p.y);

    // 边缘虚线动画
    float time_offset = - TIME * speed;
    float head1 = fract(time_offset / total_len) * total_len;
    float head2 = fract((time_offset + total_len * 0.5) / total_len) * total_len;
    float dist1 = mod(t - head1 + total_len, total_len);
    float dist2 = mod(t - head2 + total_len, total_len);
    float border_dash = pow(max(clamp(1.0 - (dist1 / dash_length), 0.0, 1.0), clamp(1.0 - (dist2 / dash_length), 0.0, 1.0)), fade_hardness);

    // --- 3. 中心加载逻辑 (开口圆环) ---
    vec2 to_center = p - center;
    float dist_to_center = length(to_center);
    // 动态计算半径 (有上限)
    float radius = min(min(rect_size.x, rect_size.y) * loading_scale_factor, max_loading_radius);

    // 3a. 距离遮罩 (画出空心圆环)
    float ring_dist_mask = smoothstep(loading_thickness, loading_thickness - 1.0, abs(dist_to_center - radius));

    // 3b. 极坐标角度遮罩 (画出开口)
    float angle = atan(to_center.y, to_center.x);
    // 归一化角度到 [0, 1]，加上旋转动画
    // 加上偏移量 0.5 只是为了调整初始开口位置
    float rotated_angle_norm = fract((angle + 3.14159) / 6.28318 + TIME * loading_speed * 0.2 + 0.5);

    // 只有角度在 [0, ring_arc_length] 范围内的像素才显示
    // 使用 smoothstep 让开口的边缘干净且无锯齿
    float arc_mask = smoothstep(ring_arc_length + arc_smoothing, ring_arc_length, rotated_angle_norm);

    // 组合遮罩：圆环 + 开口
    float loading_final = ring_dist_mask * arc_mask;

    // --- 4. 合并输出 ---
    COLOR = line_color;
    COLOR.a *= max(border_mask * border_dash, loading_final);
}