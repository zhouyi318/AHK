; ===== 找图模块（AHK 原生 ImageSearch 封装）=====
; 零成本、无需注册大漠，前台模式足够稳定

class ImageHelper {
    ; 在指定矩形区域找图
    ; sim: 相似度 0~1（越大越严格），内部转为 ImageSearch 的颜色容差
    ; 返回 true 找到并输出坐标；false 未找到
    FindPic(x1, y1, x2, y2, imgPath, sim, &outX, &outY) {
        ; 把相似度转成容差：sim 越高容差越小
        ; sim=0.9 -> 容差约25；sim=0.8 -> 容差约51
        tolerance := Round((1 - Float(sim)) * 255)
        if (tolerance < 0)
            tolerance := 0
        opts := "*" tolerance

        ; ImageSearch v2 只有 7 个参数，选项要拼进图片路径前
        ; 返回：1=找到，0=未找到
        ret := ImageSearch(&fx, &fy, x1, y1, x2, y2, opts " " imgPath)
        if ret {
            outX := fx
            outY := fy
            return true
        }
        return false
    }

    ; 找色（取某点颜色是否匹配）
    ; 返回 true 表示该点颜色与目标色在容差内一致
    FindColor(x, y, targetColor, variation := 20) {
        pixel := PixelGetColor(x, y)
        return this.ColorMatch(pixel, targetColor, variation)
    }

    ; 在区域内找色
    FindColorInArea(x1, y1, x2, y2, targetColor, variation, &outX, &outY) {
        ret := PixelSearch(&fx, &fy, x1, y1, x2, y2, targetColor, variation)
        if ret {
            outX := fx
            outY := fy
            return true
        }
        return false
    }

    ; 比较两个颜色是否在容差内（简单 RGB 分量比较）
    ColorMatch(c1, c2, variation) {
        r1 := (c1 >> 16) & 0xFF
        g1 := (c1 >> 8) & 0xFF
        b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF
        g2 := (c2 >> 8) & 0xFF
        b2 := c2 & 0xFF
        return (Abs(r1 - r2) <= variation) && (Abs(g1 - g2) <= variation) && (Abs(b1 - b2) <= variation)
    }
}
