package engine

Statistic :: struct {
    min:        f64,
    max:        f64,
    average:    f64,
    count:      i32,
    total:      f64,
}

statistic_begin :: proc(stat: ^Statistic) {
    stat.min = max(f64)
    stat.max = min(f64)
    stat.average = 0.0
    stat.count = 0
    stat.total = 0.0
}

statistic_accumulate :: proc(stat: ^Statistic, value: f64) {
    stat.count += 1

    if stat.min > value {
        stat.min = value
    }

    if stat.max < value {
        stat.max = value
    }

    stat.average += value
    stat.total += value
}

statistic_end :: proc(stat: ^Statistic) {
    if stat.count > 0 {
        stat.average /= f64(stat.count)
    } else {
        stat.min = 0.0
        stat.max = 0.0
    }
}
