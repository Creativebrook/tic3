from itertools import product


def idx(x, y, z, n):
    return x + y*n + z*n*n


def inside(p, n):
    return all(0 <= v < n for v in p)


def generate(n):
    dirs = []
    for dz, dy, dx in product(range(-1, 2), repeat=3):
        if dx == dy == dz == 0:
            continue
        if dz > 0 or (dz == 0 and dy > 0) or (dz == 0 and dy == 0 and dx > 0):
            dirs.append((dx, dy, dz))
    lines = []
    for z, y, x in product(range(n), repeat=3):
        s = (x, y, z)
        for dx, dy, dz in dirs:
            e = (x + dx*(n-1), y + dy*(n-1), z + dz*(n-1))
            if not inside(e, n):
                continue
            before = (x-dx, y-dy, z-dz)
            if inside(before, n):
                continue
            lines.append(tuple(idx(x+dx*k, y+dy*k, z+dz*k, n) for k in range(n)))
    return lines


def test_counts():
    assert len(generate(3)) == 49
    assert len(generate(4)) == 76
    assert len(generate(5)) == 109


def test_unique():
    for n in (3, 4, 5):
        canonical = {tuple(sorted(line)) for line in generate(n)}
        assert len(canonical) == len(generate(n))


def test_space_diagonals_present():
    for n in (3, 4, 5):
        lines = {tuple(line) for line in generate(n)}
        main = tuple(idx(k, k, k, n) for k in range(n))
        assert main in lines


if __name__ == "__main__":
    test_counts()
    test_unique()
    test_space_diagonals_present()
    print("OK")
