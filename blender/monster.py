# THE NEST — монстр (олений череп, рога, рёбра, когти) для Роблокса.
#
# Скрипт строит модель по частям тела R15: каждая часть (голова, торс, руки, ноги)
# — отдельный меш. В игре каждый меш приваривается к своей части тела игрока,
# поэтому монстр двигается обычными анимациями Роблокса.
#
# Запуск (из папки проекта):
#   blender --background --factory-startup --python blender/monster.py -- preview   (картинки)
#   blender --background --factory-startup --python blender/monster.py -- export    (FBX + картинки)
#
# Что получается в blender/out/:
#   monster_preview.png — вид спереди, сзади, слева, справа (как на макете)
#   monster.fbx         — все 15 частей (импорт в Studio через 3D Importer)
#   palette.png         — текстура с цветами (вшита в FBX)
#   monster.blend       — файл Blender, если захочется поправить руками
# И ещё src/shared/MonsterMeshData.luau — где каждая часть сидит на теле (для игры).
#
# Все координаты ниже — как в Роблоксе: X вправо (правая рука монстра), Y вверх,
# −Z вперёд (куда смотрит монстр). Каждая часть строится вокруг центра своей части тела.

import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "out")
DATA_FILE = os.path.join(ROOT, "src", "shared", "MonsterMeshData.luau")

rng = random.Random(1989)

# ---------------------------------------------------------------------
# Цвета (палитра). Каждый цвет — квадратик на текстуре palette.png
# ---------------------------------------------------------------------
COLORS = {
    "BONE": (168, 152, 118),
    "BONE_DARK": (116, 100, 76),
    "ANTLER": (30, 25, 22),
    "BARK": (66, 52, 38),
    "BARK_DARK": (50, 40, 30),
    "MOSS": (62, 84, 44),
    "MOSS_DARK": (40, 54, 32),
    "CLOTH": (40, 31, 24),
    "CLAW": (22, 19, 17),
    "CAVITY": (14, 10, 9),
    "FLESH": (78, 34, 30),
    "SLIME": (60, 78, 34),
    "STRAND": (22, 17, 15),
    "BLOOD": (70, 16, 13),
    "EYE": (210, 30, 16),  # красные глаза
    "FUR": (112, 86, 62),  # оленьи уши
}
NAMES = list(COLORS.keys())
GRID = 4  # 4×4 квадратика
SW = 64  # пикселей в квадратике


def make_palette(path):
    size = GRID * SW
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 3] = 1
    nrng = np.random.default_rng(7)
    for i, name in enumerate(NAMES):
        col = np.array(COLORS[name], dtype=np.float32) / 255
        gx, gy = i % GRID, i // GRID
        coarse = np.kron(nrng.random((8, 8)), np.ones((8, 8)))
        fine = nrng.random((SW, SW))
        k = 0.72 + 0.3 * coarse + 0.16 * fine
        if name in ("BONE", "BONE_DARK"):
            k = np.where(fine < 0.06, k * 0.55, k)  # тёмные крапинки грязи
        tile = np.clip(col[None, None, :] * k[..., None], 0, 1)
        img[gy * SW:(gy + 1) * SW, gx * SW:(gx + 1) * SW, :3] = tile
    im = bpy.data.images.new("MonsterPalette", size, size, alpha=False)
    im.pixels.foreach_set(img.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return im


def swatch_uv(name):
    i = NAMES.index(name)
    gx, gy = i % GRID, i // GRID
    m = 0.12  # отступ от края квадратика
    u = (gx + m + rng.random() * (1 - 2 * m)) / GRID
    v = (gy + m + rng.random() * (1 - 2 * m)) / GRID
    return (u, v)


# ---------------------------------------------------------------------
# Строитель одной части: вершины, грани, цвет и гладкость каждой грани
# ---------------------------------------------------------------------
def T(x, y, z):
    return Matrix.Translation((x, y, z))


def RX(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def RY(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def RZ(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


class Piece:
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []  # (индексы, цвет, гладкая?)
        self.stack = [Matrix.Identity(4)]
        self.marks = {}

    @property
    def M(self):
        return self.stack[-1]

    def push(self, m):
        self.stack.append(self.stack[-1] @ m)

    def pop(self):
        self.stack.pop()

    def v(self, p):
        self.verts.append(self.M @ Vector(p))
        return len(self.verts) - 1

    def f(self, idx, color, smooth=True):
        self.faces.append((list(idx), color, smooth))

    def mark(self, name, p):
        self.marks[name] = self.M @ Vector(p)

    # метка с поворотом: точка + углы (порядок как у CFrame.Angles в Роблоксе)
    def mark_frame(self, name, m):
        full = self.M @ m
        self.marks[name] = full.to_translation()
        self.marks[name + "Rot"] = full.to_3x3().normalized().to_euler("ZYX")

    # --- эллипсоид (шар), lump — «бугристость». Большие шары делаем плотнее (для рельефа)
    def ball(self, c, r, color, rot=None, segs=10, rings=7, lump=0.0):
        rmax = max(r)
        if rmax > 0.2:
            segs = max(segs, min(22, int(8 + rmax * 24)))
            rings = max(rings, min(15, int(6 + rmax * 16)))
        self.push(T(*c) @ (rot or Matrix.Identity(4)))
        top = self.v((0, r[1], 0))
        ring_idx = []
        for i in range(1, rings):
            th = math.pi * i / rings
            row = []
            for j in range(segs):
                ph = 2 * math.pi * j / segs
                k = 1 + (rng.uniform(-lump, lump) if lump else 0)
                row.append(self.v((r[0] * math.sin(th) * math.cos(ph) * k, r[1] * math.cos(th) * k, r[2] * math.sin(th) * math.sin(ph) * k)))
            ring_idx.append(row)
        bot = self.v((0, -r[1], 0))
        for j in range(segs):
            j2 = (j + 1) % segs
            self.f((top, ring_idx[0][j2], ring_idx[0][j]), color)
            self.f((bot, ring_idx[-1][j], ring_idx[-1][j2]), color)
        for i in range(len(ring_idx) - 1):
            a, b = ring_idx[i], ring_idx[i + 1]
            for j in range(segs):
                j2 = (j + 1) % segs
                self.f((a[j], a[j2], b[j2], b[j]), color)
        self.pop()

    # --- труба по ломаной: кости, рога, когти, шипы. Радиус 0 на конце — острый кончик
    def tube(self, pts, radii, color, sides=7, lump=0.0, closed=False, step=None):
        P = [Vector(p) for p in pts]
        if step and not closed:
            P, radii = resample(P, list(radii), step)  # плавная кривая и больше колец
        n = len(P)
        tang = []
        for i in range(n):
            if closed:
                t = P[(i + 1) % n] - P[i - 1]
            elif i == 0:
                t = P[1] - P[0]
            elif i == n - 1:
                t = P[-1] - P[-2]
            else:
                t = P[i + 1] - P[i - 1]
            tang.append(t.normalized())
        ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = (ref - tang[0] * ref.dot(tang[0])).normalized()
        rings = []
        for i in range(n):
            if i > 0:
                nrm = (nrm - tang[i] * nrm.dot(tang[i])).normalized()
            bin_ = tang[i].cross(nrm)
            r = radii[i]
            if r < 0.004:
                rings.append([self.v(P[i])])
                continue
            row = []
            for j in range(sides):
                a = 2 * math.pi * j / sides
                k = 1 + (rng.uniform(-lump, lump) if lump else 0)
                row.append(self.v(P[i] + (nrm * math.cos(a) + bin_ * math.sin(a)) * r * k))
            rings.append(row)
        segs = range(n) if closed else range(n - 1)
        for i in segs:
            a, b = rings[i], rings[(i + 1) % n]
            if len(b) == 1:
                for j in range(sides):
                    self.f((a[j], a[(j + 1) % sides], b[0]), color)
            elif len(a) == 1:
                for j in range(sides):
                    self.f((a[0], b[(j + 1) % sides], b[j]), color)
            else:
                for j in range(sides):
                    j2 = (j + 1) % sides
                    self.f((a[j], a[j2], b[j2], b[j]), color)
        if not closed:
            if len(rings[0]) > 1:
                c = self.v(P[0])
                for j in range(sides):
                    self.f((c, rings[0][j], rings[0][(j + 1) % sides]), color)
            if len(rings[-1]) > 1:
                c = self.v(P[-1])
                for j in range(sides):
                    self.f((c, rings[-1][(j + 1) % sides], rings[-1][j]), color)

    # --- кость с толщиной от a до b и суставами-шариками на концах
    def bone(self, a, b, r, color, knob=True, r2=None):
        self.tube([a, b], [r, r2 if r2 is not None else r], color, sides=8)
        if knob:
            self.ball(a, (r * 1.35,) * 3, color, segs=8, rings=6)
            self.ball(b, (r * 1.35,) * 3, color, segs=8, rings=6)

    # --- шип: конус от основания в направлении dir
    def spike(self, base, d, length, r, color="BONE"):
        d = Vector(d).normalized()
        b = Vector(base)
        self.tube([b, b + d * length * 0.55, b + d * length], [r, r * 0.55, 0], color, sides=6)

    # --- коробка (ткань, челюсть, зубы)
    def box(self, c, s, color, rot=None):
        self.push(T(*c) @ (rot or Matrix.Identity(4)))
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        idx = [self.v((x, y, z)) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.f([idx[k] for k in q], color, smooth=False)
        self.pop()

    # --- рваный лоскут ткани: сверху ровный, снизу зубцы. Висит вниз из точки top
    def rag(self, top, width, length, color="CLOTH", rot=None, teeth=3, thick=0.035):
        self.push(T(*top) @ (rot or Matrix.Identity(4)))
        pts = [(-width / 2, 0), (width / 2, 0)]
        n = teeth * 2
        for i in range(n + 1):
            x = width / 2 - width * i / n
            deep = length * (rng.uniform(0.85, 1.0) if i % 2 == 0 else rng.uniform(0.55, 0.8))
            pts.append((x, -deep))
        wave = [rng.uniform(-0.04, 0.04) for _ in pts]
        for side in (-1, 1):
            z = side * thick / 2
            centre = self.v((0, -0.02, z))
            ids = [self.v((x, y, z + w * min(1, -y))) for (x, y), w in zip(pts, wave)]
            ring = ids[1:] + ids[:1]  # обход по краю, начиная с правого верха
            for i in range(len(ring)):
                a, b = ring[i], ring[(i + 1) % len(ring)]
                self.f((centre, a, b) if side > 0 else (centre, b, a), color, smooth=False)
        self.pop()

    # --- маленький череп (на плечах и руках). Смотрит в −Z
    def skull(self, c, size, rot=None):
        self.push(T(*c) @ (rot or Matrix.Identity(4)) @ Matrix.Scale(size, 4))
        self.ball((0, 0.05, 0.05), (0.5, 0.45, 0.5), "BONE", lump=0.03)
        for x in (-0.2, 0.2):
            self.ball((x, 0.02, -0.4), (0.14, 0.15, 0.08), "CAVITY", segs=8, rings=5)
        self.ball((0, -0.17, -0.45), (0.06, 0.08, 0.05), "CAVITY", segs=6, rings=4)
        self.box((0, -0.36, -0.15), (0.55, 0.22, 0.5), "BONE_DARK")
        for x in (-0.18, -0.06, 0.06, 0.18):
            self.box((x, -0.27, -0.4), (0.07, 0.1, 0.05), "BONE")
        self.pop()

    # --- кусок гнилой коры вокруг кости (кольцо-«обмотка»)
    def wrap(self, y, h, r, color, x=0.0, z=0.0):
        self.tube([(x, y + h / 2, z), (x, y, z), (x, y - h / 2, z)], [r * 0.9, r, r * 0.9], color, sides=10, lump=0.12, step=0.04)

    # --- корень-лиана, спиралью обвивает кость
    def vine(self, y0, y1, r, turns, color="BARK", phase=0.0, thick=0.028):
        n = int(turns * 12) + 2
        pts = []
        for i in range(n):
            t = i / (n - 1)
            a = phase + t * turns * 2 * math.pi
            rr = r * (1 + 0.08 * math.sin(t * 17))
            pts.append((rr * math.cos(a), y0 + (y1 - y0) * t, rr * math.sin(a)))
        self.tube(pts, [thick] * (n - 1) + [thick * 0.3], color, sides=5)

    # --- тёмные наросты-«глазки» по коре
    def nodules(self, y0, y1, r, count, side):
        for _ in range(count):
            a = rng.uniform(-1.2, 1.2) + (0 if side > 0 else math.pi)
            y = rng.uniform(y1, y0)
            q = rng.uniform(0.035, 0.06)
            self.ball((r * math.cos(a), y, r * math.sin(a)), (q, q, q), "CAVITY", segs=7, rings=5)
            self.ball((r * 1.04 * math.cos(a), y, r * 1.04 * math.sin(a)), (q * 1.5, q * 1.5, q * 0.6), "MOSS_DARK", segs=7, rings=4)

    def to_object(self, mat, rest):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([rb2bl(p) for p in self.verts], [], [fc[0] for fc in self.faces])
        # живая поверхность: кору и мох «мнём» плавным шумом вдоль нормалей
        amp = [0.0] * len(self.verts)
        for idx, color, _ in self.faces:
            for i in idx:
                amp[i] = max(amp[i], RELIEF.get(color, 0.0))
        off = rb2bl(Vector(rest))
        normals = [v.normal.copy() for v in mesh.vertices]
        for v in mesh.vertices:
            a = amp[v.index]
            if a > 0:
                q = (v.co + off) * 5.0
                n = noise.noise(q) + 0.5 * noise.noise(q * 2.7) + 0.25 * noise.noise(q * 6.1)
                v.co += normals[v.index] * a * n
        # центр меша = центр габаритов (так Роблокс ставит MeshPart)
        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        lo, hi = Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))
        c_bl = (lo + hi) / 2
        for v in mesh.vertices:
            v.co -= c_bl
        centre = Vector((c_bl.x, c_bl.z, -c_bl.y))  # обратно в координаты Роблокса
        size = Vector((hi.x - lo.x, hi.z - lo.z, hi.y - lo.y))
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, (_, color, smooth) in zip(mesh.polygons, self.faces):
            poly.use_smooth = smooth
            for li in poly.loop_indices:
                uv.data[li].uv = swatch_uv(color)
        mesh.materials.append(mat)
        mesh.validate()
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = off + c_bl
        bpy.context.scene.collection.objects.link(obj)
        return obj, centre, size


# сила рельефа по цветам (в студах)
RELIEF = {
    "BARK": 0.035, "BARK_DARK": 0.035, "MOSS": 0.05, "MOSS_DARK": 0.05,
    "BONE": 0.008, "BONE_DARK": 0.014, "ANTLER": 0.014, "FLESH": 0.025, "FUR": 0.01,
}


def onto(c, r, p):
    # точка p, прижатая к поверхности эллипсоида (центр c, радиусы r) — чтобы потёк лёг на кость
    c, p = Vector(c), Vector(p)
    d = p - c
    k = math.sqrt((d.x / r[0]) ** 2 + (d.y / r[1]) ** 2 + (d.z / r[2]) ** 2) or 1
    return c + d * (1.02 / k)


def resample(P, R, step):
    # кривая Катмулла–Рома через точки: каждые step студов новое кольцо
    out_p, out_r = [P[0]], [R[0]]
    for i in range(len(P) - 1):
        p0 = P[i - 1] if i > 0 else P[i]
        p1, p2 = P[i], P[i + 1]
        p3 = P[i + 2] if i + 2 < len(P) else P[i + 1]
        n = max(1, int((p2 - p1).length / step))
        for k in range(1, n + 1):
            t = k / n
            q = 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
            out_p.append(q)
            out_r.append(R[i] + (R[i + 1] - R[i]) * t)
    return out_p, out_r


def rb2bl(p):
    # Роблокс (Y вверх, −Z вперёд) → Blender (Z вверх). Монстр в Blender смотрит в +Y
    return Vector((p.x, -p.z, p.y))


# ---------------------------------------------------------------------
# Размеры и положение частей обычного R15 (масштаб 1), земля на Y = 0
# ---------------------------------------------------------------------
BASE = {
    "Head": (1.2, 1.2, 1.2),
    "UpperTorso": (2, 1.6, 1),
    "LowerTorso": (2, 0.4, 1),
    "LeftUpperArm": (1, 1.169, 1), "RightUpperArm": (1, 1.169, 1),
    "LeftLowerArm": (1, 1.052, 1), "RightLowerArm": (1, 1.052, 1),
    "LeftHand": (1, 0.3, 1), "RightHand": (1, 0.3, 1),
    "LeftUpperLeg": (1, 1.217, 1), "RightUpperLeg": (1, 1.217, 1),
    "LeftLowerLeg": (1, 1.193, 1), "RightLowerLeg": (1, 1.193, 1),
    "LeftFoot": (1, 0.3, 1), "RightFoot": (1, 0.3, 1),
}
REST = {
    "Head": (0, 5.25, 0),
    "UpperTorso": (0, 3.85, 0),
    "LowerTorso": (0, 2.85, 0),
    "LeftUpperArm": (-1.5, 4.05, 0), "RightUpperArm": (1.5, 4.05, 0),
    "LeftLowerArm": (-1.5, 2.95, 0), "RightLowerArm": (1.5, 2.95, 0),
    "LeftHand": (-1.5, 2.27, 0), "RightHand": (1.5, 2.27, 0),
    "LeftUpperLeg": (-0.5, 2.05, 0), "RightUpperLeg": (0.5, 2.05, 0),
    "LeftLowerLeg": (-0.5, 0.85, 0), "RightLowerLeg": (0.5, 0.85, 0),
    "LeftFoot": (-0.5, 0.15, 0), "RightFoot": (0.5, 0.15, 0),
}
TORSO_TILT = -24  # монстр сильно сутулится вперёд
ARM_Z = -0.36  # руки вперёд, под горбы плеч


# ---------------------------------------------------------------------
# Голова: олений череп с трещинами, рога, шея
# ---------------------------------------------------------------------
def build_head():
    p = Piece("Head")
    s = 0.92
    # шея: позвонки от плеч к затылку
    for i in range(7):
        t = i / 6
        y = -0.72 + t * 0.4
        z = -0.25 - t * 0.72
        p.ball((0, y, z + 0.05), (0.13, 0.09, 0.13), "BONE_DARK", segs=8, rings=5)
        p.spike((0, y + 0.05, z + 0.1), (0, 1, 0.5), 0.14, 0.04, "BONE_DARK")
    # голова низко, вытянута вперёд перед горбом и смотрит вперёд-вниз (как на макете)
    p.push(T(0, -0.32, -1.08) @ RX(-46) @ Matrix.Scale(s, 4))
    # череп: вытянутый лоб плавно переходит в узкую морду
    p.ball((0, 0.16, 0.08), (0.45, 0.42, 0.5), "BONE", segs=14, rings=10, lump=0.025)
    p.ball((0, 0.02, -0.36), (0.41, 0.34, 0.45), "BONE", segs=12, rings=8)
    p.ball((0, 0.3, -0.12), (0.2, 0.12, 0.42), "BONE_DARK", segs=10, rings=6)  # гребень на лбу
    p.ball((0, -0.18, -0.88), (0.3, 0.24, 0.62), "BONE", rot=RX(-10), segs=12, rings=8)
    p.ball((0, -0.32, -1.38), (0.2, 0.15, 0.21), "BONE_DARK", segs=10, rings=6)
    for x in (-0.08, 0.08):
        p.ball((x, -0.3, -1.56), (0.05, 0.06, 0.05), "CAVITY", segs=6, rings=4)
    # длинная носовая щель по морде и тёмные ямки на скулах
    p.ball((0, 0.03, -1.0), (0.07, 0.05, 0.32), "CAVITY", rot=RX(-10), segs=8, rings=6)
    for x in (-0.2, 0.2):
        p.ball((x, -0.08, -1.0), (0.04, 0.04, 0.12), "CAVITY", segs=6, rings=4)
    # скулы
    for x in (-0.36, 0.36):
        p.ball((x, -0.12, -0.55), (0.12, 0.1, 0.3), "BONE_DARK", segs=8, rings=5)
    # хищные глаза: узкий миндалевидный разрез с острыми уголками, косо вверх к вискам
    # (внутренний угол ниже, у носа; внешний выше). Сверху нависает тяжёлое костяное веко.
    for x in (-0.3, 0.3):
        sx = 1 if x > 0 else -1
        slant = RZ(sx * 24)
        # тёмная глазница той же формы, чуть больше глаза
        p.push(T(x, 0.1, -0.6) @ slant)
        p.tube([(-0.27, -0.01, 0.05), (-0.14, 0.01, 0.01), (0, 0.02, 0), (0.14, 0.01, 0.01), (0.27, -0.01, 0.05)],
               [0.01, 0.085, 0.11, 0.085, 0.01], "CAVITY", sides=10, step=0.03)
        p.pop()
        # сам глаз: веретено, сужается в острые кончики (в игре поверх — слабый Neon той же формы)
        p.push(T(x, 0.1, -0.665) @ slant)
        p.tube([(-0.2, 0.0, 0.05), (-0.1, 0.012, 0.015), (0, 0.016, 0), (0.1, 0.012, 0.015), (0.2, 0.0, 0.05)],
               [0, 0.04, 0.055, 0.04, 0], "EYE", sides=10, step=0.025)
        # нависшее веко: срезает верх глаза — взгляд исподлобья
        p.tube([(-0.22, 0.035, 0.03), (-0.1, 0.07, -0.02), (0, 0.08, -0.035), (0.1, 0.07, -0.02), (0.22, 0.035, 0.03)],
               [0.015, 0.04, 0.046, 0.04, 0.015], "BONE_DARK", sides=8, step=0.03)
        p.mark_frame("EyeL" if sx < 0 else "EyeR", Matrix.Identity(4))
        p.pop()
        # надбровье: острые костяные выступы над глазом, скошенные к носу
        for k in range(3):
            bx = x - sx * 0.12 + sx * 0.12 * k
            p.spike((bx, 0.26 - 0.04 * k, -0.6), (sx * 0.2, 0.35, -1), 0.14 - 0.03 * k, 0.04, "BONE_DARK")
        # впалые щёки: тёмная яма под глазом
        p.ball((x * 1.05, -0.12, -0.7), (0.07, 0.08, 0.16), "CAVITY", rot=RX(-15), segs=8, rings=5)
    # трещины по черепу: «ломаные» прямо по поверхности (их стало больше и они глубже)
    for _ in range(16):
        th, ph = rng.uniform(0.15, 1.3), rng.uniform(0, 2 * math.pi)
        pts = []
        for _k in range(6):
            pts.append((0.45 * 1.02 * math.sin(th) * math.cos(ph), 0.16 + 0.42 * 1.02 * math.cos(th), 0.08 + 0.5 * 1.02 * math.sin(th) * math.sin(ph)))
            th = min(1.5, th + rng.uniform(0.05, 0.2))
            ph += rng.uniform(-0.3, 0.3)
        p.tube(pts, [0.022] * 5 + [0], "CAVITY", sides=4)
    # пролом во лбу: дыра с острыми краями
    p.ball((0.14, 0.5, -0.05), (0.12, 0.06, 0.1), "CAVITY", segs=10, rings=6)
    for k in range(6):
        ang = k / 6 * 2 * math.pi
        p.spike((0.14 + 0.12 * math.cos(ang), 0.52, -0.05 + 0.1 * math.sin(ang)), (math.cos(ang), 0.6, math.sin(ang)), 0.07, 0.025, "BONE")
    # верхние зубы: длинные, тонкие, кривые иглы
    for i in range(7):
        z = -0.48 - i * 0.13
        for x in (-0.17, 0.17):
            p.spike((x * (1 - i * 0.06), -0.34, z), (rng.uniform(-0.25, 0.25), -1, rng.uniform(-0.3, 0.15)), rng.uniform(0.16, 0.32), 0.026, "BONE")
    # чёрная глотка между челюстями — открытая пасть читается как дыра
    p.ball((0, -0.45, -0.75), (0.2, 0.1, 0.45), "CAVITY", segs=10, rings=6)
    # нижняя челюсть широко раскрыта (шарнир сзади), снизу торчат клыки
    p.push(T(0, -0.42, -0.4) @ RX(26) @ T(0, 0.42, 0.4))
    p.box((0, -0.5, -0.85), (0.42, 0.12, 0.95), "BONE_DARK", rot=RX(-6))
    for i in range(6):
        z = -0.5 - i * 0.14
        for x in (-0.15, 0.15):
            p.spike((x * (1 - i * 0.07), -0.44, z), (rng.uniform(-0.2, 0.2), 1, rng.uniform(-0.25, 0.05)), rng.uniform(0.16, 0.3), 0.028, "BONE")
    # тягучие нити слюны/жил между челюстями
    for x in (-0.12, -0.04, 0.06, 0.14):
        z = rng.uniform(-0.7, -1.15)
        p.tube([(x, -0.34, z), (x + 0.01, -0.62, z - 0.04), (x, -0.5, z - 0.02)], [0.012, 0.02, 0.012], "SLIME" if x > 0 else "BLOOD", sides=4)
    p.pop()
    # кровь стекает из пасти и с подбородка (вниз по миру, а голова наклонена)
    down = Vector((0, -0.69, -0.72))
    for x, z, ln in ((-0.18, -0.6, 0.45), (0.2, -0.7, 0.6), (0.05, -1.2, 0.55)):
        top = Vector((x, -0.5, z))
        pts = [top + down * ln * t + Vector((0.02 * math.sin(t * 7), 0, 0)) for t in (0, 0.35, 0.7, 1.0)]
        p.tube(pts, [0.028, 0.022, 0.016, 0.01], "BLOOD", sides=5, step=0.05)
        p.ball(pts[-1], (0.028, 0.04, 0.028), "BLOOD", segs=6, rings=4)
    # гнилая кожа клочьями висит со скул
    for sx in (-1, 1):
        for k in range(2):
            p.rag((sx * (0.34 + 0.05 * k), -0.15, -0.5 - 0.22 * k), 0.12, rng.uniform(0.3, 0.5), "FLESH", rot=RX(46) @ RY(sx * 80), teeth=2, thick=0.02)
    # кровавые слёзы из глазниц вниз по морде
    for sx in (-1, 1):
        pts = [onto((0, 0.02, -0.36), (0.41, 0.34, 0.45), (sx * 0.28, -0.04, -0.7))]
        for t in (0.25, 0.5, 0.75, 1.0):
            pts.append(onto((0, -0.18, -0.88), (0.3, 0.24, 0.62), (sx * (0.27 - 0.08 * t), -0.1 - 0.12 * t, -0.75 - 0.32 * t)))
        p.tube(pts, [0.026, 0.024, 0.022, 0.018, 0.012], "BLOOD", sides=5, step=0.04)
        p.ball(pts[-1], (0.025, 0.035, 0.025), "BLOOD", segs=6, rings=4)
    # оленьи уши: торчат в стороны, чуть вниз
    for side in (-1, 1):
        p.push(T(side * 0.42, 0.34, 0.12) @ RZ(side * -58) @ RX(-10))
        p.ball((0, 0.26, 0), (0.19, 0.3, 0.07), "FUR", segs=10, rings=6)
        p.ball((0, 0.56, 0), (0.1, 0.2, 0.05), "FUR", segs=8, rings=5)  # острый кончик
        p.ball((0, 0.32, -0.04), (0.11, 0.3, 0.04), "BONE_DARK", segs=8, rings=5)
        p.pop()
    # рога: невысокие, расходятся в стороны «лирой», отростки смотрят вверх
    p.push(T(0, 0.55, 0.15) @ RX(42) @ T(0, -0.55, -0.15))
    for side in (-1, 1):
        def a(x, y, z):
            return Vector((side * x, y, z))
        main = [a(0.3, 0.55, 0.15), a(0.62, 0.92, 0.25), a(0.92, 1.3, 0.2), a(1.1, 1.72, 0.05), a(1.12, 2.12, -0.08)]
        p.ball(main[0], (0.15, 0.11, 0.15), "ANTLER", lump=0.15)
        p.tube(main, [0.11, 0.095, 0.075, 0.055, 0], "ANTLER", sides=8, lump=0.06, step=0.08)
        for base, mid, tip in (
            (main[1], a(0.5, 1.3, 0.15), a(0.44, 1.62, 0.05)),
            (main[2], a(0.74, 1.72, 0.12), a(0.7, 2.05, 0.02)),
            (main[2], a(1.32, 1.55, 0.25), a(1.5, 1.85, 0.2)),
            (main[3], a(1.38, 1.98, 0.05), a(1.46, 2.28, 0.0)),
        ):
            p.tube([base, mid, tip], [0.06, 0.04, 0], "ANTLER", sides=6, step=0.08)
        # бугристая «розетка» у основания рога
        for k in range(5):
            ang = k / 5 * 2 * math.pi
            p.ball(main[0] + Vector((0.1 * math.cos(ang), 0.05, 0.1 * math.sin(ang))), (0.06, 0.05, 0.06), "ANTLER", segs=6, rings=4)
        # «обереги» на рогах: на нитях висят косточки, зубы и маленький череп
        for j, base in enumerate((main[1], main[2], main[3])):
            ln = rng.uniform(0.35, 0.7)
            end = base + Vector((side * 0.04, -ln, 0.03))
            p.tube([base, base + Vector((side * 0.02, -ln * 0.5, 0.05)), end], [0.012, 0.012, 0.01], "STRAND", sides=4)
            if j == 1 and side > 0:
                p.skull(end + Vector((0, -0.08, 0)), 0.16)
            elif j == 0:
                p.bone(end + Vector((-0.08, -0.03, 0)), end + Vector((0.08, -0.05, 0)), 0.018, "BONE")
            else:
                p.spike(end, (0, -1, 0), 0.12, 0.025, "BONE")
    p.pop()
    p.pop()
    return p


# ---------------------------------------------------------------------
# Грудь: рёбра, позвоночник, горбы мха с черепами и шипами, шарф
# ---------------------------------------------------------------------
def build_upper_torso():
    p = Piece("UpperTorso")
    p.push(T(0, -0.8, 0) @ RX(TORSO_TILT) @ T(0, 0.8, 0))
    w, d = 0.6, 0.4
    # тёмная пустота внутри, кусок плоти
    p.ball((0, 0.1, 0.05), (0.52, 0.66, 0.34), "CAVITY")
    p.ball((0.12, -0.2, -0.05), (0.28, 0.3, 0.22), "FLESH", lump=0.1)
    # рёбра: дуги от грудины к позвоночнику
    widths = [0.7, 0.86, 0.96, 1.0, 1.0, 0.95, 0.86]
    for i, wf in enumerate(widths):
        ys = 0.62 - i * 0.17
        th0 = 0.55 if i >= 5 else 0.12  # нижние рёбра «плавающие»
        for side in (-1, 1):
            pts = []
            for k in range(9):
                th = th0 + (math.pi - 0.18 - th0) * k / 8
                pts.append((side * w * wf * math.sin(th), ys - 0.16 * (1 + math.cos(th)) / 2, -d * math.cos(th)))
            p.tube(pts, [0.05] * 9, "BONE", sides=6)
    # грудина и ключицы
    p.tube([(0, 0.68, -d - 0.02), (0, 0.2, -d - 0.03), (0, -0.3, -d)], [0.065, 0.06, 0.03], "BONE_DARK", sides=6)
    for side in (-1, 1):
        p.tube([(side * 0.06, 0.74, -d), (side * 0.4, 0.8, -0.25), (side * 0.72, 0.78, -0.02)], [0.05, 0.055, 0.06], "BONE", sides=6)
    # позвоночник сзади: позвонки и остистые отростки
    for i in range(12):
        y = 0.85 - i * 0.15
        p.ball((0, y, d + 0.05), (0.13, 0.07, 0.11), "BONE", segs=8, rings=5)
        p.spike((0, y, d + 0.1), (0, -0.5, 1), 0.12, 0.05, "BONE_DARK")
    # позвоночник видно и спереди: сквозь живот до таза, с кусками плоти
    for i in range(5):
        y = -0.5 - i * 0.12
        p.ball((0, y, 0.12), (0.11, 0.06, 0.09), "BONE", segs=8, rings=5)
    p.ball((-0.1, -0.75, 0.0), (0.09, 0.12, 0.07), "FLESH", lump=0.2)
    # внутри грудной клетки застрял чей-то череп
    p.skull((0.1, 0.02, -0.17), 0.36, rot=RZ(18) @ RX(-10))
    # жилы и плоть натянуты поперёк рёбер
    for x in (-0.38, -0.2, 0.3, 0.42):
        y0 = rng.uniform(0.3, 0.55)
        p.tube([(x, y0, -0.41), (x + 0.03, y0 - 0.3, -0.5), (x - 0.02, y0 - 0.65, -0.42)], [0.02, 0.028, 0.018], "FLESH" if x < 0 else "BLOOD", sides=5, step=0.06)
    # рваная плоть у основания шеи
    for x in (-0.15, 0.12):
        p.ball((x, 0.82, -0.25), (0.11, 0.08, 0.1), "FLESH", lump=0.25)
    p.tube([(0.15, -0.4, -0.1), (0.2, -0.65, -0.05), (0.08, -0.85, -0.02)], [0.04, 0.035, 0.02], "BLOOD", sides=5)
    # плечи: горбы мха, чёрные бугры, черепа, торчащие кости и шипы
    for side in (-1, 1):
        sh = Vector((side * 0.78, 0.72, 0.05))
        p.ball(sh, (0.6, 0.44, 0.64), "MOSS", lump=0.14, segs=12, rings=8)
        p.ball(sh + Vector((side * -0.3, -0.18, 0.32)), (0.45, 0.34, 0.48), "MOSS_DARK", lump=0.15)
        p.ball(sh + Vector((side * 0.25, 0.26, -0.12)), (0.34, 0.26, 0.4), "MOSS_DARK", lump=0.15)
        for _ in range(7):
            a, b = rng.uniform(0, 2 * math.pi), rng.uniform(0.2, 1.3)
            pos = sh + Vector((0.6 * math.sin(b) * math.cos(a), 0.44 * math.cos(b), 0.64 * math.sin(b) * math.sin(a)))
            p.ball(pos, (0.08, 0.08, 0.08), "BARK_DARK", segs=6, rings=4)
        p.skull(sh + Vector((side * 0.12, 0.22, -0.52)), 0.52, rot=RX(-15))
        p.skull(sh + Vector((side * 0.15, 0.12, 0.6)), 0.46, rot=RY(180))
        p.skull(sh + Vector((side * -0.25, -0.32, 0.62)), 0.4, rot=RY(180) @ RX(10))
        # кости торчат из мха в стороны
        for k in range(2):
            base = sh + Vector((side * 0.2, 0.1 - k * 0.2, -0.25 + k * 0.45))
            tip = base + Vector((side * 0.55, 0.25 - k * 0.1, -0.15 + k * 0.2))
            p.bone(base, tip, 0.05, "BONE")
        # шипы
        for k in range(6):
            base = sh + Vector((side * (0.3 + 0.05 * (k % 2)), 0.3, -0.45 + k * 0.18))
            p.spike(base, (side * 0.6, 1, (k - 2.5) * 0.25), rng.uniform(0.35, 0.6), 0.06)
        # густые костяные шипы на горбу спины (видно сбоку на макете)
        for k in range(9):
            a = rng.uniform(0.25, 0.85) * math.pi
            b = rng.uniform(0.3, 1.0)
            dirv = Vector((0.6 * math.sin(b) * math.cos(a) * side, 0.44 * math.cos(b), 0.64 * math.sin(b) * math.sin(a)))
            base = sh + dirv * 0.95
            p.spike(base, dirv.normalized() + Vector((0, 0.5, 0.3)), rng.uniform(0.22, 0.42), 0.045)
        # длинные тёмные «космы» висят со спины и плеч
        for k in range(5):
            top = sh + Vector((side * rng.uniform(-0.2, 0.45), -0.2, rng.uniform(0.25, 0.6)))
            ln = rng.uniform(0.9, 1.6)
            pts = [top + Vector((side * 0.04 * math.sin(i * 1.7), -ln * i / 5, 0.05 * math.sin(i * 1.3) + 0.03 * i)) for i in range(6)]
            p.tube(pts, [0.04, 0.036, 0.032, 0.026, 0.018, 0], "STRAND" if k % 2 else "BARK_DARK", sides=5, step=0.1)
        # зелёная слизь капает с мха
        for k in range(4):
            top = sh + Vector((side * rng.uniform(0.0, 0.45), -0.32, rng.uniform(-0.45, 0.45)))
            ln = rng.uniform(0.3, 0.65)
            p.tube([top, top + Vector((0, -ln * 0.5, 0.01)), top + Vector((0, -ln, 0))], [0.04, 0.028, 0.018], "SLIME", sides=5)
            p.ball(top + Vector((0, -ln, 0)), (0.045, 0.06, 0.045), "SLIME", segs=6, rings=4)
        # тёмные нити свисают с плеч
        for k in range(3):
            top = sh + Vector((side * (0.3 + 0.1 * k), -0.3, -0.35 + k * 0.3))
            ln = rng.uniform(0.5, 1.1)
            p.tube([top, top + Vector((side * 0.05, -ln * 0.5, 0)), top + Vector((side * 0.02, -ln, 0.02))], [0.025, 0.02, 0], "STRAND", sides=4)
    # мешок-нарост сбоку живота
    p.ball((-0.35, -0.6, -0.12), (0.27, 0.3, 0.24), "MOSS_DARK", lump=0.12)
    # слизь и нити свисают с рёбер
    for i in range(7):
        x = rng.uniform(-0.45, 0.45)
        y = rng.uniform(-0.2, 0.4)
        ln = rng.uniform(0.35, 0.9)
        z = -d * 1.02
        col = "SLIME" if i % 2 == 0 else "STRAND"
        p.tube([(x, y, z), (x + 0.02, y - ln * 0.5, z - 0.02), (x, y - ln, z)], [0.025, 0.02, 0.012], col, sides=5)
        if col == "SLIME":
            p.ball((x, y - ln, z), (0.05, 0.07, 0.05), "SLIME", segs=6, rings=4)
    # рваный шарф на шее
    p.tube([(0.42 * math.cos(a), 0.86, 0.32 * math.sin(a) + 0.02) for a in [2 * math.pi * k / 10 for k in range(10)]], [0.1] * 10, "CLOTH", sides=6, lump=0.2, closed=True)
    # тёмный рваный капюшон-накидка на груди: два слоя лоскутов
    for layer, (r, ln0, ln1, n) in enumerate(((0.46, 0.45, 0.9, 11), (0.52, 0.25, 0.55, 9))):
        for k in range(n):
            a = math.pi * (0.08 + 0.84 * k / (n - 1)) + math.pi  # спереди
            top = (r * math.cos(a), 0.86 - layer * 0.04, (r - 0.1) * math.sin(a) - 0.02 * layer)
            p.rag(top, 0.26, rng.uniform(ln0, ln1), rot=RY(-math.degrees(a) - 90) @ RX(14 + 6 * layer), teeth=2)
    # сзади накидка короче
    for k in range(6):
        a = math.pi * (0.12 + 0.76 * k / 5)
        top = (0.46 * math.cos(a), 0.86, 0.36 * math.sin(a))
        p.rag(top, 0.24, rng.uniform(0.2, 0.4), rot=RY(-math.degrees(a) - 90) @ RX(10), teeth=1)
    p.mark("Flies", (0, 1.1, 0))
    p.pop()
    return p


# ---------------------------------------------------------------------
# Таз: кости, пояс, набедренная повязка из рваных лоскутов
# ---------------------------------------------------------------------
def build_lower_torso():
    p = Piece("LowerTorso")
    p.ball((0, 0, 0), (0.5, 0.2, 0.32), "BONE_DARK")
    for side in (-1, 1):
        p.ball((side * 0.38, 0.1, 0.02), (0.2, 0.2, 0.27), "BONE", rot=RZ(side * 20))
    for i in range(3):
        p.ball((0, 0.15 - i * 0.14, 0.42), (0.11, 0.06, 0.09), "BONE", segs=8, rings=5)
    p.tube([(0.66 * math.cos(a), 0.06, 0.46 * math.sin(a)) for a in [2 * math.pi * k / 12 for k in range(12)]], [0.07] * 12, "BARK_DARK", sides=6, lump=0.15, closed=True)
    # лоскуты спереди и сзади
    for zs in (-1, 1):
        for k in range(6):
            x = -0.55 + k * 0.22
            z = zs * 0.47
            p.rag((x, 0.08, z), 0.26, rng.uniform(1.0, 1.55), rot=RX(-zs * 7) @ RZ(rng.uniform(-5, 5)), teeth=2)
    # длинные тонкие полоски-лохмотья спереди
    for k in range(6):
        x = rng.uniform(-0.45, 0.45)
        p.rag((x, 0.0, -0.5), 0.08, rng.uniform(1.5, 2.0), rot=RX(6) @ RZ(rng.uniform(-6, 6)), teeth=1)
    # кости и черепок на поясе
    p.skull((0.3, 0.05, -0.52), 0.26)
    for x in (-0.35, -0.12):
        p.bone((x, 0.12, -0.5), (x + 0.08, -0.25, -0.53), 0.03, "BONE")
    # по бокам короче
    for side in (-1, 1):
        for k in range(2):
            z = -0.2 + k * 0.4
            p.rag((side * 0.66, 0.08, z), 0.26, rng.uniform(0.6, 0.9), rot=RY(90) @ RX(side * 7), teeth=1)
    return p


# ---------------------------------------------------------------------
# Руки: тонкие кости, кора, мох, шипы, черепа, длинные когти-серпы
# ---------------------------------------------------------------------
def build_upper_arm(name, side):
    p = Piece(name)
    p.push(T(0, -0.04, ARM_Z))
    # плечевая кость: сверху обросла корой, снизу голая — видно кость до локтя
    p.bone((0, 0.5, 0), (0, -0.56, 0), 0.12, "BONE", r2=0.1)
    p.ball((0, 0.5, 0), (0.2, 0.19, 0.2), "BONE")
    p.ball((0, -0.5, 0.02), (0.14, 0.12, 0.13), "BONE", lump=0.05)  # бугор кости у локтя
    p.tube([(0, 0.42, 0), (0, 0.15, 0), (0, -0.12, 0)], [0.18, 0.21, 0.15], "BARK", sides=12, lump=0.12, step=0.05)
    p.vine(0.42, -0.4, 0.17, 1.4, phase=side, thick=0.024)
    p.nodules(0.3, -0.05, 0.19, 3, side)
    for k, y in enumerate((0.3, 0.02)):
        p.wrap(y, 0.13, 0.21, "BARK" if k % 2 else "BARK_DARK")
    # жилы вдоль голой кости
    for k in range(2):
        a = side * (0.6 + k * 1.4)
        p.tube([(0.1 * math.cos(a), -0.1, 0.1 * math.sin(a)), (0.13 * math.cos(a), -0.3, 0.13 * math.sin(a)), (0.1 * math.cos(a), -0.48, 0.1 * math.sin(a))],
               [0.018, 0.024, 0.016], "FLESH", sides=5, step=0.05)
    p.ball((side * 0.08, 0.15, 0.12), (0.18, 0.2, 0.15), "MOSS_DARK", lump=0.2)
    p.ball((-side * 0.1, 0.1, -0.1), (0.12, 0.14, 0.1), "MOSS", lump=0.2)
    p.skull((side * 0.25, 0.1, -0.02), 0.38, rot=RY(-side * 90))
    p.spike((side * 0.11, -0.3, 0.05), (side, 0.4, 0.2), 0.38, 0.05)
    p.spike((side * 0.16, 0.3, 0.1), (side, 0.6, 0.4), 0.32, 0.05)
    p.pop()
    return p


def build_lower_arm(name, side):
    p = Piece(name)
    p.push(T(0, 0, ARM_Z))
    p.ball((0, 0.5, 0), (0.16, 0.16, 0.16), "BONE")  # локоть
    # две голые кости предплечья (лучевая и локтевая), чуть расходятся посередине
    for dx, dz, r in ((-0.075, 0.03, 0.055), (0.075, -0.03, 0.046)):
        p.tube([(dx * 0.5, 0.48, dz), (dx * 1.15, 0.0, dz * 1.6), (dx * 0.8, -0.5, dz)], [r * 1.2, r * 0.8, r * 1.15], "BONE", sides=8, step=0.06)
        p.ball((dx * 0.8, -0.5, dz), (r * 1.45, r * 1.3, r * 1.45), "BONE_DARK", segs=8, rings=5)
    # кора только у локтя, ниже кости открыты; обрывок коры на запястье
    p.tube([(0, 0.44, 0), (0, 0.22, 0), (0, 0.0, 0)], [0.2, 0.25, 0.15], "BARK_DARK", sides=12, lump=0.12, step=0.05)
    p.wrap(0.3, 0.12, 0.25, "BARK")
    p.wrap(-0.44, 0.07, 0.12, "BARK_DARK")
    # жилы и плоть натянуты между костями
    for k in range(3):
        y0 = rng.uniform(-0.08, -0.36)
        p.tube([(-0.07, y0, 0.03), (0.0, y0 - 0.05, rng.uniform(-0.05, 0.05)), (0.07, y0 - 0.1, -0.03)], [0.016, 0.022, 0.016], "FLESH" if k else "BLOOD", sides=5)
    p.vine(0.42, -0.45, 0.14, 1.3, phase=2 + side, thick=0.022)
    p.nodules(0.38, 0.06, 0.24, 3, side)
    # ещё одна кость торчит из коры назад
    p.bone((side * 0.1, 0.1, 0.18), (side * 0.2, 0.3, 0.42), 0.035, "BONE")
    p.ball((side * 0.1, 0.18, -0.12), (0.15, 0.16, 0.12), "MOSS_DARK", lump=0.2)
    p.ball((-side * 0.12, 0.32, 0.08), (0.1, 0.12, 0.09), "MOSS", lump=0.2)
    for k in range(5):
        y = 0.38 - k * 0.19
        base = 0.22 if y > 0.02 else 0.1  # на коре шипы снаружи, ниже растут прямо из кости
        p.spike((side * base, y, 0.03), (side, 0.5, rng.uniform(-0.2, 0.3)), rng.uniform(0.3, 0.45), 0.05)
    p.bone((side * 0.08, 0.2, -0.2), (side * 0.15, 0.42, -0.36), 0.04, "BONE")
    p.skull((side * 0.27, 0.2, 0.02), 0.3, rot=RY(-side * 90))
    for k in range(2):
        top = (rng.uniform(-0.1, 0.1), -0.42, 0.15)
        ln = rng.uniform(0.3, 0.6)
        p.tube([top, (top[0], -0.42 - ln * 0.5, 0.17), (top[0], -0.42 - ln, 0.16)], [0.02, 0.015, 0], "STRAND", sides=4)
    p.pop()
    return p


def build_hand(name, side):
    p = Piece(name)
    p.push(T(0, 0, ARM_Z))
    # концы костей предплечья и кучка мелких косточек запястья
    for dx in (-0.06, 0.06):
        p.bone((dx, 0.12, 0), (dx * 0.8, -0.26, 0), 0.045, "BONE", knob=False)
    for k in range(6):
        a = k / 6 * 2 * math.pi
        p.ball((0.07 * math.cos(a), -0.3 + 0.03 * math.sin(2 * a), 0.06 * math.sin(a)), (0.055, 0.05, 0.05), "BONE_DARK", segs=7, rings=5, lump=0.1)
    p.ball((0, -0.4, -0.02), (0.13, 0.07, 0.1), "BARK_DARK", lump=0.15)  # остаток высохшей ладони
    # 4 костлявых пальца: пястная кость + 3 фаланги с костяшками, каждый сустав
    # сгибается сильнее — пальцы загнуты крючьями внутрь (к ногам), разной длины
    down = Vector((0, -1, 0))
    inward = Vector((-side, 0, -0.35)).normalized()
    lengths = (0.85, 1.0, 0.95, 0.78)
    for i in range(4):
        k = (i - 1.5) / 1.5
        spread = Vector((side * 0.05 * k, 0, k * 0.32))
        pos = Vector((side * 0.02, -0.38, k * 0.1 - 0.02))
        for s_len, curl, r in ((0.28, 0, 0.05), (0.24, 14, 0.047), (0.2, 32, 0.042), (0.15, 55, 0.036)):
            a = math.radians(curl)
            d = (down * math.cos(a) + inward * math.sin(a) + spread * (1 - curl / 90)).normalized()
            nxt = pos + d * s_len * lengths[i]
            p.bone(pos, nxt, r, "BONE", knob=False, r2=r * 0.8)
            p.ball(nxt, (r * 1.45, r * 1.45, r * 1.45), "BONE_DARK", segs=7, rings=5)  # костяшка
            pos = nxt
        # коготь-крюк продолжает изгиб пальца
        claw = [pos]
        for curl, ln in ((78, 0.15), (108, 0.13), (138, 0.11)):
            a = math.radians(curl)
            claw.append(claw[-1] + (down * math.cos(a) + inward * math.sin(a)).normalized() * ln * lengths[i])
        p.tube(claw[:3], [0.045, 0.036, 0.022], "CLAW", sides=6, step=0.03)
        p.tube(claw[2:], [0.022, 0], "BLOOD", sides=6, step=0.03)  # кончики в засохшей крови
    # большой палец: две фаланги и коготь, смотрит вперёд-внутрь
    pos = Vector((0, -0.36, -0.14))
    thumb_dir = (down * 0.55 + Vector((0, 0, -0.75)) + inward * 0.3).normalized()
    for s_len, r in ((0.2, 0.048), (0.16, 0.042)):
        nxt = pos + thumb_dir * s_len
        p.bone(pos, nxt, r, "BONE", knob=False, r2=r * 0.85)
        p.ball(nxt, (r * 1.45, r * 1.45, r * 1.45), "BONE_DARK", segs=7, rings=5)
        pos = nxt
        thumb_dir = (thumb_dir + inward * 0.4 + down * 0.2).normalized()
    p.tube([pos, pos + thumb_dir * 0.13, pos + (thumb_dir + inward * 0.8).normalized() * 0.24], [0.04, 0.026, 0], "CLAW", sides=6, step=0.03)
    p.pop()
    return p


# ---------------------------------------------------------------------
# Ноги: кости, наколенники, кора с шипами, когтистые ступни
# ---------------------------------------------------------------------
def build_upper_leg(name, side):
    p = Piece(name)
    p.bone((0, 0.55, 0), (0, -0.58, 0), 0.14, "BONE", r2=0.12)
    p.tube([(0, 0.45, 0), (0, 0.1, 0), (0, -0.4, 0)], [0.2, 0.23, 0.18], "BARK", sides=12, lump=0.1, step=0.06)
    p.vine(0.45, -0.45, 0.22, 1.3, phase=1 + side)
    p.nodules(0.3, -0.3, 0.22, 3, side)
    for k in range(2):
        p.spike((side * 0.2, 0.15 - k * 0.3, 0.05), (side, 0.3, 0.3), rng.uniform(0.2, 0.3), 0.04)
    for k, y in enumerate((0.25, -0.15)):
        p.wrap(y, 0.18, 0.24, "BARK_DARK" if k else "CLOTH")
    p.ball((side * 0.08, -0.05, 0.12), (0.17, 0.2, 0.13), "MOSS_DARK", lump=0.2)
    p.ball((-side * 0.1, 0.25, -0.12), (0.11, 0.13, 0.09), "MOSS", lump=0.2)
    p.ball((0, -0.56, -0.08), (0.19, 0.18, 0.15), "BONE", lump=0.06)  # коленная кость
    p.ball((0, -0.5, -0.18), (0.13, 0.12, 0.08), "BONE_DARK", lump=0.1)
    return p


def build_lower_leg(name, side):
    p = Piece(name)
    p.bone((0, 0.55, 0), (0, -0.55, 0), 0.11, "BONE_DARK", r2=0.09)
    p.tube([(0, 0.42, 0), (0, 0.05, 0), (0, -0.3, 0), (0, -0.5, 0)], [0.19, 0.23, 0.21, 0.16], "BARK_DARK", sides=12, lump=0.1, step=0.06)
    p.vine(0.42, -0.5, 0.22, 1.5, phase=3 + side)
    p.nodules(0.3, -0.4, 0.22, 3, side)
    p.wrap(0.15, 0.12, 0.23, "BARK")
    p.ball((-side * 0.08, 0.1, -0.14), (0.14, 0.18, 0.09), "MOSS_DARK", lump=0.2)
    p.ball((side * 0.1, -0.2, 0.12), (0.1, 0.12, 0.08), "MOSS", lump=0.2)
    for k in range(3):
        y = 0.25 - k * 0.25
        p.spike((side * 0.18, y, 0.05), (side, 0.35, 0.4), rng.uniform(0.3, 0.42), 0.05)
    p.spike((0, 0.1, 0.2), (0, 0.3, 1), 0.3, 0.05)
    p.spike((0, -0.15, 0.19), (0, 0.2, 1), 0.25, 0.045)
    p.ball((side * 0.05, -0.42, -0.1), (0.1, 0.12, 0.05), "BLOOD", lump=0.2)
    top = (side * 0.1, 0.0, -0.1)
    p.tube([top, (side * 0.12, -0.3, -0.12), (side * 0.11, -0.55, -0.11)], [0.02, 0.016, 0], "STRAND", sides=4)
    return p


def build_foot(name, side):
    p = Piece(name)
    p.ball((0, 0.12, 0), (0.16, 0.15, 0.16), "BONE_DARK")
    p.ball((0, -0.02, -0.12), (0.27, 0.14, 0.4), "BARK_DARK", lump=0.12)
    for i in (-1, 0, 1):
        a = (i * 0.12, -0.03, -0.38)
        b = (i * 0.15, -0.04, -0.6)
        p.tube([a, b], [0.06, 0.05], "BONE_DARK", sides=6)
        p.ball(b, (0.06, 0.06, 0.06), "BONE_DARK", segs=6, rings=4)
        p.tube([b, (i * 0.17, -0.06, -0.75), (i * 0.18, -0.15, -0.86)], [0.05, 0.03, 0], "CLAW", sides=6)
    p.tube([(0, -0.02, 0.2), (0, -0.07, 0.35), (0, -0.15, 0.45)], [0.05, 0.03, 0], "CLAW", sides=6)
    p.ball((side * 0.1, 0.05, -0.2), (0.08, 0.05, 0.12), "BLOOD", lump=0.2)
    return p


def build_all():
    pieces = [build_head(), build_upper_torso(), build_lower_torso()]
    for side_name, side in (("Left", -1), ("Right", 1)):
        pieces += [
            build_upper_arm(f"{side_name}UpperArm", side),
            build_lower_arm(f"{side_name}LowerArm", side),
            build_hand(f"{side_name}Hand", side),
            build_upper_leg(f"{side_name}UpperLeg", side),
            build_lower_leg(f"{side_name}LowerLeg", side),
            build_foot(f"{side_name}Foot", side),
        ]
    return pieces


# ---------------------------------------------------------------------
# Сцена, превью, экспорт
# ---------------------------------------------------------------------
def make_material(palette):
    mat = bpy.data.materials.new("MonsterPalette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.nodes.active = tex
    return mat


# ---------------------------------------------------------------------
# Реалистичная текстура: запекаем в картинку цвет + грязь + тени (AO) + мох + потёртости.
# Части собраны в 4 атласа (Роблокс всё равно ужимает картинку до 1024).
# ---------------------------------------------------------------------
BAKE_SIZE = 1024
EYE_GLOW = 2.5  # сила свечения глаз в Blender (слабое)
BAKE_GROUPS = {
    "Head": ["Head"],
    "Torso": ["UpperTorso"],
    "Legs": ["LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"],
    "Arms": ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"],
}


def bake_shader(palette):
    mat = bpy.data.materials.new("MonsterBake")
    mat.use_nodes = True
    nt = mat.node_tree
    N, L = nt.nodes, nt.links.new
    for n in list(N):
        N.remove(n)
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L(emit.outputs["Emission"], out.inputs["Surface"])
    uv = N.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    pal = N.new("ShaderNodeTexImage")
    pal.image = palette
    pal.interpolation = "Closest"
    L(uv.outputs["UV"], pal.inputs["Vector"])
    geo = N.new("ShaderNodeNewGeometry")

    def noise_fac(scale, detail, rough=0.6):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        L(geo.outputs["Position"], n.inputs["Vector"])
        return n.outputs["Fac"]

    def remap(sock, a, b, c, d):
        m = N.new("ShaderNodeMapRange")
        m.clamp = True
        L(sock, m.inputs["Value"])
        m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = a, b
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = c, d
        return m.outputs["Result"]

    def scale(col, k):
        v = N.new("ShaderNodeVectorMath")
        v.operation = "SCALE"
        L(col, v.inputs[0])
        L(k, v.inputs["Scale"])
        return v.outputs["Vector"]

    def fmul(a, b):
        m = N.new("ShaderNodeMath")
        m.operation = "MULTIPLY"
        L(a, m.inputs[0])
        L(b, m.inputs[1])
        return m.outputs["Value"]

    col = pal.outputs["Color"]
    # мелкая грязь и пятна разной яркости
    col = scale(col, remap(noise_fac(7, 10), 0.3, 0.7, 0.7, 1.15))
    col = scale(col, remap(noise_fac(1.6, 4), 0.45, 0.62, 1.0, 0.6))
    col = scale(col, remap(noise_fac(60, 2), 0.35, 0.65, 0.82, 1.08))
    # потёки грязи сверху вниз: шум, растянутый по вертикали
    mp = N.new("ShaderNodeMapping")
    L(geo.outputs["Position"], mp.inputs["Vector"])
    mp.inputs["Scale"].default_value = (9, 9, 1.2)
    streak = N.new("ShaderNodeTexNoise")
    streak.inputs["Detail"].default_value = 6
    L(mp.outputs["Vector"], streak.inputs["Vector"])
    col = scale(col, remap(streak.outputs["Fac"], 0.5, 0.68, 1.0, 0.55))
    # зелёный налёт мха пятнами сверху поверхностей
    sep = N.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs["Vector"])
    up = remap(sep.outputs["Z"], -0.2, 0.8, 0.0, 1.0)
    moss_mask = fmul(remap(noise_fac(3.2, 6), 0.5, 0.6, 0.0, 0.55), up)
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    a_in = next(s for s in mix.inputs if s.identifier == "A_Color")
    b_in = next(s for s in mix.inputs if s.identifier == "B_Color")
    L(moss_mask, mix.inputs["Factor"])
    L(col, a_in)
    b_in.default_value = (0.045, 0.07, 0.025, 1)
    col = next(s for s in mix.outputs if s.identifier == "Result_Color")
    # затенение в щелях между деталями (ambient occlusion)
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.inputs["Distance"].default_value = 0.35
    col = scale(col, remap(ao.outputs["AO"], 0.0, 1.0, 0.22, 1.0))
    # выпуклые края светлее, впадины темнее (потёртости)
    col = scale(col, remap(geo.outputs["Pointiness"], 0.44, 0.56, 0.75, 1.2))
    L(col, emit.inputs["Color"])
    return mat


def bake_textures(objs, palette):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    by_name = {o.name: o for o in objs}
    bmat = bake_shader(palette)
    for group, names in BAKE_GROUPS.items():
        group_objs = [by_name[n] for n in names]
        img = bpy.data.images.new(f"Monster_{group}", BAKE_SIZE, BAKE_SIZE, alpha=False)
        target = bmat.node_tree.nodes.new("ShaderNodeTexImage")
        target.image = img
        bmat.node_tree.nodes.active = target
        bpy.ops.object.select_all(action="DESELECT")
        for o in group_objs:
            o.data.materials.clear()
            o.data.materials.append(bmat)
            o.data.uv_layers.active = o.data.uv_layers.new(name="Bake")
            o.select_set(True)
        bpy.context.view_layer.objects.active = group_objs[0]
        # своя развёртка для запекания: все части группы в одном квадрате
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003)
        bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
        img.filepath_raw = os.path.join(OUT, f"monster_{group.lower()}.png")
        img.file_format = "PNG"
        img.save()
        bmat.node_tree.nodes.remove(target)
        # итоговый материал: только запечённая картинка, палитра больше не нужна
        fmat = bpy.data.materials.new(f"Monster_{group}")
        fmat.use_nodes = True
        nt = fmat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.85
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        # слабое свечение глаз в Blender: светится только ярко-красное (глаза), а не кровь
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tex.outputs["Color"], sep.inputs["Color"])
        # «краснота» = R − 3·G: у глаз большая, у кости, крови, плоти и меха ≈ 0 или меньше
        g3 = nt.nodes.new("ShaderNodeMath")
        g3.operation = "MULTIPLY"
        nt.links.new(sep.outputs["Green"], g3.inputs[0])
        g3.inputs[1].default_value = 3.0
        diff = nt.nodes.new("ShaderNodeMath")
        diff.operation = "SUBTRACT"
        nt.links.new(sep.outputs["Red"], diff.inputs[0])
        nt.links.new(g3.outputs["Value"], diff.inputs[1])
        mask = nt.nodes.new("ShaderNodeMapRange")
        mask.clamp = True
        nt.links.new(diff.outputs["Value"], mask.inputs["Value"])
        mask.inputs["From Min"].default_value, mask.inputs["From Max"].default_value = 0.07, 0.16
        mask.inputs["To Min"].default_value, mask.inputs["To Max"].default_value = 0.0, EYE_GLOW
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        nt.links.new(mask.outputs["Result"], bsdf.inputs["Emission Strength"])
        nt.nodes.active = tex
        for o in group_objs:
            o.data.materials.clear()
            o.data.materials.append(fmat)
            o.data.uv_layers.remove(o.data.uv_layers["UVMap"])
        print(f"  запечено: monster_{group.lower()}.png")
    bpy.data.materials.remove(bmat)


def deg(e):
    return Vector((math.degrees(e.x), math.degrees(e.y), math.degrees(e.z)))


def fmt(v):
    return f"Vector3.new({v.x:.3f}, {v.y:.3f}, {v.z:.3f})"


def write_data(info, marks):
    lines = [
        "-- СГЕНЕРИРОВАНО скриптом blender/monster.py — не правь руками, запусти скрипт заново.",
        "-- Где каждый меш монстра сидит на своей части тела R15 (в координатах этой части):",
        "--   offset — центр меша относительно центра части тела, size — размер меша,",
        "--   base — размер части тела, под который строили (обычный R15, масштаб 1),",
        "--   rest — где стоит часть тела в позе «статуя» (земля на Y = 0).",
        "return {",
        "\tparts = {",
    ]
    for name, (centre, size) in info.items():
        lines.append(f"\t\t{name} = {{ offset = {fmt(centre)}, size = {fmt(size)}, base = {fmt(Vector(BASE[name]))}, rest = {fmt(Vector(REST[name]))} }},")
    lines += [
        "\t},",
        "\t-- красные глаза (Neon) в координатах головы",
        f"\teyes = {{ {fmt(marks['EyeL'])}, {fmt(marks['EyeR'])} }},",
        "\t-- повороты глаз (градусы, для CFrame.Angles): узкий косой разрез",
        f"\teyeAngles = {{ {fmt(deg(marks['EyeLRot']))}, {fmt(deg(marks['EyeRRot']))} }},",
        "\t-- откуда вылетают мухи (в координатах UpperTorso)",
        f"\tflies = {fmt(marks['Flies'])},",
        "}",
        "",
    ]
    with open(DATA_FILE, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_views(path):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.82, 0.82, 0.82)
    scene.display.render_aa = "8"
    scene.view_settings.view_transform = "Standard"
    W, H = 500, 760
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 9.2
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = Vector((0, 0, 4.1))
    # монстр смотрит в +Y Blender. Камеры: спереди, сзади, слева (его левый бок), справа
    views = [("front", (0, 20, 4.1)), ("back", (0, -20, 4.1)), ("side1", (20, 0, 4.1)), ("side2", (-20, 0, 4.1))]
    tiles = []
    for tag, pos in views:
        cam.location = Vector(pos)
        look_at(cam, centre)
        f = os.path.join(OUT, f"view_{tag}.png")
        scene.render.filepath = f
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(f)
        arr = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
        tiles.append(arr)
        bpy.data.images.remove(im)
    sheet = np.concatenate(tiles, axis=1)
    out = bpy.data.images.new("Sheet", W * 4, H, alpha=False)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.objects.remove(cam)


# ---------------------------------------------------------------------
# Риг: скелет R15 (как у персонажа Роблокса). Кости стоят в суставах, где Роблокс
# сгибает тело. Каждая часть монстра целиком висит на своей кости (как в игре).
# Координаты как в Роблоксе: (кость-родитель, начало кости = сустав, конец кости)
# ---------------------------------------------------------------------
JOINTS = {
    "HumanoidRootPart": (None, (0, 2.35, 0), (0, 2.65, 0)),
    "LowerTorso": ("HumanoidRootPart", (0, 2.65, 0), (0, 3.05, 0)),
    "UpperTorso": ("LowerTorso", (0, 3.05, 0), (0, 4.65, 0)),
    "Head": ("UpperTorso", (0, 4.65, 0), (0, 5.85, 0)),
}
for _s, _S in ((-1, "Left"), (1, "Right")):
    JOINTS[f"{_S}UpperArm"] = ("UpperTorso", (_s * 1.0, 4.41, 0), (_s * 1.5, 3.47, 0))
    JOINTS[f"{_S}LowerArm"] = (f"{_S}UpperArm", (_s * 1.5, 3.47, 0), (_s * 1.5, 2.42, 0))
    JOINTS[f"{_S}Hand"] = (f"{_S}LowerArm", (_s * 1.5, 2.42, 0), (_s * 1.5, 1.6, 0))
    JOINTS[f"{_S}UpperLeg"] = ("LowerTorso", (_s * 0.5, 2.65, 0), (_s * 0.5, 1.44, 0))
    JOINTS[f"{_S}LowerLeg"] = (f"{_S}UpperLeg", (_s * 0.5, 1.44, 0), (_s * 0.5, 0.25, 0))
    JOINTS[f"{_S}Foot"] = (f"{_S}LowerLeg", (_s * 0.5, 0.25, 0), (_s * 0.5, 0.1, -0.6))

# жуткая поза для проверки рига (градусы, по осям кости X, Y, Z)
# у рук и ног +X = вперёд; у торса −X = наклон вперёд; Z у головы = наклон набок
CREEPY_POSE = {
    "UpperTorso": (-14, 0, 0),
    "Head": (0, 0, 28),
    "RightUpperArm": (62, 0, 0),
    "RightLowerArm": (38, 0, 0),
    "RightHand": (20, 0, 0),
    "LeftUpperArm": (14, 0, 0),
    "LeftLowerArm": (22, 0, 0),
    "LeftUpperLeg": (16, 0, 0),
    "LeftLowerLeg": (-26, 0, 0),
    "RightUpperLeg": (-8, 0, 0),
    "RightLowerLeg": (-14, 0, 0),
}


def build_rig(objs):
    arm = bpy.data.armatures.new("MonsterRig")
    arm.display_type = "STICK"
    rig = bpy.data.objects.new("MonsterRig", arm)
    rig.show_in_front = True
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (parent, head, tail) in JOINTS.items():
        b = arm.edit_bones.new(name)
        b.head = rb2bl(Vector(head))
        b.tail = rb2bl(Vector(tail))
        if parent:
            b.parent = arm.edit_bones[parent]
        if head[1] > tail[1]:
            # кости рук и ног: ось Z смотрит вперёд, поэтому поворот по X = махнуть вперёд/назад
            b.align_roll(Vector((0, 1, 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    # каждая часть: группа вершин с весом 1 на свою кость + модификатор Armature
    for o in objs:
        bone = o.name.removeprefix("M_")
        vg = o.vertex_groups.new(name=bone)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        mw = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = mw
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    print(f"  риг: {len(arm.bones)} костей")
    return rig


def set_pose(rig, pose):
    for pb in rig.pose.bones:
        rot = pose.get(pb.name, (0, 0, 0)) if pose else (0, 0, 0)
        pb.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.view_layer.update()


def render_pose(rig, path):
    # кадр 3/4 спереди в жуткой позе; потом поза сбрасывается обратно
    scene = bpy.context.scene
    set_pose(rig, CREEPY_POSE)
    rig.hide_render = True
    cam_data = bpy.data.cameras.new("PoseCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 8.6
    cam = bpy.data.objects.new("PoseCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = Vector((9, 16, 6.5))
    look_at(cam, Vector((0, 0, 3.6)))
    scene.render.resolution_x, scene.render.resolution_y = 700, 760
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    set_pose(rig, None)


# ---------------------------------------------------------------------
# Анимации (30 кадров в секунду). Каждая — список ключевых поз:
#   (кадр, {кость: (X, Y, Z) градусы}, {кость: (x, y, z) сдвиг в студах})
# Оси: у рук и ног +X = вперёд, Z у правой руки + = к телу, − = в сторону (у левой наоборот);
# замах над головой: X 150 и Z +35 у правой (−35 у левой);
# у торса −X = наклон вперёд, Y = поворот (+ правым плечом вперёд), Z = наклон набок;
# сдвиг LowerTorso: y = вверх, z = назад (−z = рывок вперёд).
# ---------------------------------------------------------------------
FPS = 30


def cycle(n_frames, step, pose_at):
    # циклическая анимация (бег, ходьба): поза считается по фазе 0..2π
    keys = []
    for f in range(0, n_frames + 1, step):
        p = 2 * math.pi * f / n_frames
        rot, loc = pose_at(p)
        keys.append((f, rot, loc))
    return keys


def run_pose(p):
    c, s = math.cos(p), math.sin(p)
    rot = {
        "LeftUpperLeg": (38 * c, 0, 0),
        "RightUpperLeg": (-38 * c, 0, 0),
        "LeftLowerLeg": (-15 - 65 * max(0, -s), 0, 0),
        "RightLowerLeg": (-15 - 65 * max(0, s), 0, 0),
        "LeftFoot": (10 * c, 0, 0),
        "RightFoot": (-10 * c, 0, 0),
        "LeftUpperArm": (25 - 35 * c, 0, 8),
        "RightUpperArm": (25 + 35 * c, 0, -8),
        "LeftLowerArm": (35 + 12 * s, 0, 0),
        "RightLowerArm": (35 - 12 * s, 0, 0),
        "LeftHand": (15, 0, 0),
        "RightHand": (15, 0, 0),
        "UpperTorso": (-22 + 4 * math.cos(2 * p), 9 * c, 0),
        "Head": (20 + 4 * math.sin(2 * p), 0, 7 * s),
        "LowerTorso": (0, -7 * c, 0),
    }
    loc = {"LowerTorso": (0, -0.12 + 0.12 * math.cos(2 * p), 0)}
    return rot, loc


def carry_pose(p):
    c, s = math.cos(p), math.sin(p)
    rot = {
        # правая рука держит тело, лежащее на плечах: плечо вперёд, предплечье вверх к телу
        "RightUpperArm": (90 + 3 * s, 0, 10),
        "RightLowerArm": (120, 0, 0),
        "RightHand": (30, 0, 0),
        # левая волочится и покачивается
        "LeftUpperArm": (12 + 12 * c, 0, 6),
        "LeftLowerArm": (18, 0, 0),
        "LeftUpperLeg": (26 * c, 0, 0),
        "RightUpperLeg": (-26 * c, 0, 0),
        "LeftLowerLeg": (-10 - 42 * max(0, -s), 0, 0),
        "RightLowerLeg": (-10 - 42 * max(0, s), 0, 0),
        "UpperTorso": (-26 + 3 * math.cos(2 * p), 4 * c, -8),
        "Head": (14, 0, 6 + 4 * s),
        "LowerTorso": (0, -4 * c, 0),
    }
    loc = {"LowerTorso": (0, -0.22 + 0.08 * math.cos(2 * p), 0)}
    return rot, loc


def scream_keys():
    keys = [
        (0, {"UpperTorso": (-12, 0, 0)}, {}),
        # набирает воздух: медленно запрокидывает голову, руки расходятся
        (8, {"UpperTorso": (10, 0, 0), "Head": (40, 0, -6), "LeftUpperArm": (30, 0, 48), "RightUpperArm": (30, 0, -48),
             "LeftLowerArm": (50, 0, 0), "RightLowerArm": (50, 0, 0), "LeftUpperLeg": (-6, 0, 0), "RightUpperLeg": (-6, 0, 0)},
         {"LowerTorso": (0, 0.06, 0.25)}),
    ]
    # резкий рывок вперёд, потом рёв: мелкая плавная дрожь (ключ на каждый кадр — без «лагов»),
    # голова медленно склоняется набок
    for f in range(12, 43):
        t = f - 12
        tilt = min(1.0, t / 20) * 12  # медленный жуткий наклон головы
        keys.append((f, {
            "UpperTorso": (-32 + 1.5 * math.sin(t * 0.9), 2 * math.sin(t * 0.7), 0),
            "Head": (-22 + 3 * math.sin(t * 1.3), 0, tilt + 3 * math.sin(t * 1.9)),
            "LeftUpperArm": (66 + 2 * math.sin(t * 1.1), 0, 76 + 3 * math.sin(t * 1.6)),
            "RightUpperArm": (66 + 2 * math.sin(t * 1.2 + 1), 0, -76 - 3 * math.sin(t * 1.5 + 1)),
            "LeftLowerArm": (22, 0, 0), "RightLowerArm": (22, 0, 0),
            "LeftHand": (-35 + 4 * math.sin(t * 2.1), 0, 0), "RightHand": (-35 + 4 * math.sin(t * 2.0 + 1), 0, 0),
            "LeftUpperLeg": (26, 0, 0), "LeftLowerLeg": (-36, 0, 0),
            "RightUpperLeg": (-14, 0, 0), "RightLowerLeg": (-6, 0, 0),
        }, {"LowerTorso": (0, -0.14, -0.85)}))
    # медленно приходит в себя
    keys.append((56, {"UpperTorso": (-12, 0, 0)}, {}))
    return keys


ANIMS = {
    "Run": cycle(20, 2, run_pose),
    "Carry": cycle(32, 2, carry_pose),
    "Scream": scream_keys(),
    # удар правой лапой наискосок
    "Attack": [
        (0, {"UpperTorso": (-12, 0, 0)}, {}),
        (6, {"UpperTorso": (6, -25, 0), "Head": (10, 0, 0), "RightUpperArm": (150, 0, 35), "RightLowerArm": (70, 0, 0),
             "RightHand": (-30, 0, 0), "LeftUpperArm": (20, 0, 0)}, {"LowerTorso": (0, 0, 0.15)}),
        # удар: локоть остаётся согнутым, кисть с когтями «загребает» (рука не выпрямляется палкой)
        (10, {"UpperTorso": (-25, 30, 0), "Head": (-15, 0, 0), "RightUpperArm": (45, 0, 40), "RightLowerArm": (38, 0, 0),
              "RightHand": (40, 0, 0), "LeftUpperArm": (-10, 0, 0), "LeftUpperLeg": (20, 0, 0), "LeftLowerLeg": (-25, 0, 0)},
         {"LowerTorso": (0, -0.1, -0.4)}),
        (13, {"UpperTorso": (-22, 35, 0), "Head": (-12, 0, 0), "RightUpperArm": (15, 0, 55), "RightLowerArm": (55, 0, 0),
              "RightHand": (45, 0, 0), "LeftUpperLeg": (15, 0, 0), "LeftLowerLeg": (-20, 0, 0)}, {"LowerTorso": (0, -0.1, -0.35)}),
        (20, {"UpperTorso": (-12, 0, 0)}, {}),
    ],
    # прыжок-выпад двумя лапами и укус
    "Attack2": [
        (0, {"UpperTorso": (-12, 0, 0)}, {}),
        (7, {"UpperTorso": (10, 0, 0), "Head": (22, 0, 0), "LeftUpperArm": (150, 0, -35), "RightUpperArm": (150, 0, 35),
             "LeftLowerArm": (60, 0, 0), "RightLowerArm": (60, 0, 0)}, {"LowerTorso": (0, -0.1, 0.25)}),
        (12, {"UpperTorso": (-35, 0, 0), "Head": (-30, 0, 0), "LeftUpperArm": (50, 0, -30), "RightUpperArm": (50, 0, 30),
              "LeftLowerArm": (32, 0, 0), "RightLowerArm": (32, 0, 0), "LeftHand": (40, 0, 0), "RightHand": (40, 0, 0),
              "LeftUpperLeg": (30, 0, 0), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (-20, 0, 0), "RightLowerLeg": (-10, 0, 0)},
         {"LowerTorso": (0, -0.25, -0.7)}),
        (16, {"UpperTorso": (-32, 0, 0), "Head": (-24, 0, 6), "LeftUpperArm": (45, 0, -28), "RightUpperArm": (45, 0, 28),
              "LeftLowerArm": (40, 0, 0), "RightLowerArm": (40, 0, 0), "LeftHand": (40, 0, 0), "RightHand": (40, 0, 0),
              "LeftUpperLeg": (28, 0, 0), "LeftLowerLeg": (-38, 0, 0), "RightUpperLeg": (-18, 0, 0)},
         {"LowerTorso": (0, -0.25, -0.65)}),
        (24, {"UpperTorso": (-12, 0, 0)}, {}),
    ],
}


def make_actions(rig):
    scene = bpy.context.scene
    scene.render.fps = FPS
    rig.animation_data_create()
    actions = {}
    for name, keys in ANIMS.items():
        act = bpy.data.actions.new(f"Monster_{name}")
        act.use_fake_user = True  # чтобы Blender не выкинул анимацию при сохранении
        rig.animation_data.action = act
        for frame, rot, loc in keys:
            for pb in rig.pose.bones:
                pb.rotation_euler = [math.radians(a) for a in rot.get(pb.name, (0, 0, 0))]
                pb.location = loc.get(pb.name, (0, 0, 0))
                pb.keyframe_insert("rotation_euler", frame=frame + 1)
                pb.keyframe_insert("location", frame=frame + 1)
        actions[name] = act
        print(f"  анимация {name}: {keys[-1][0] + 1} кадров")
    rig.animation_data.action = None
    set_pose(rig, None)
    return actions


def export_anims(rig, actions):
    # каждая анимация — свой FBX только со скелетом (для Animation Editor в Studio)
    scene = bpy.context.scene
    for name, act in actions.items():
        rig.animation_data.action = act
        scene.frame_start, scene.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, f"monster_anim_{name.lower()}.fbx"),
            use_selection=True,
            object_types={"ARMATURE"},
            axis_forward="-Z",
            axis_up="Y",
            add_leaf_bones=False,
            bake_anim=True,
            bake_anim_use_all_actions=False,
            bake_anim_use_nla_strips=False,
            bake_anim_force_startend_keying=True,
            bake_anim_simplify_factor=0.0,
        )
    rig.animation_data.action = actions["Run"]
    scene.frame_start, scene.frame_end = 1, 21


def main():
    mode = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "preview"
    os.makedirs(OUT, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    palette = make_palette(os.path.join(OUT, "palette.png"))
    mat = make_material(palette)
    pieces = build_all()
    info, marks, objs = {}, {}, []
    tris_total = 0
    for pc in pieces:
        obj, centre, size = pc.to_object(mat, REST[pc.name])
        objs.append(obj)
        info[pc.name] = (centre, size)
        marks.update(pc.marks)
        tris = sum(len(f[0]) - 2 for f in pc.faces)
        tris_total += tris
        print(f"  {pc.name:15s} {tris:6d} треуг.  размер {size.x:.2f} x {size.y:.2f} x {size.z:.2f}")
    print(f"  всего треугольников: {tris_total}")
    write_data(info, marks)
    bake_textures(objs, palette)
    render_views(os.path.join(OUT, "monster_preview.png"))
    if mode == "export":
        for o in objs:
            o.name = "M_" + o.name  # чтобы Studio не путал с частями тела игрока
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, "monster.fbx"),
            use_selection=True,
            object_types={"MESH"},
            axis_forward="-Z",
            axis_up="Y",
            bake_space_transform=True,
            mesh_smooth_type="FACE",
            path_mode="COPY",
            embed_textures=True,
        )
        print("THE NEST: monster.fbx готов")
    # риг строим после экспорта monster.fbx: игре нужны простые меши без скелета
    rig = build_rig(objs)
    render_pose(rig, os.path.join(OUT, "monster_pose.png"))
    actions = make_actions(rig)
    if mode == "export":
        export_anims(rig, actions)
        rig.animation_data.action = None
        set_pose(rig, None)
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, "monster_rig.fbx"),
            use_selection=True,
            object_types={"ARMATURE", "MESH"},
            axis_forward="-Z",
            axis_up="Y",
            add_leaf_bones=False,
            bake_anim=False,
            mesh_smooth_type="FACE",
            path_mode="COPY",
            embed_textures=True,
        )
        rig.animation_data.action = actions["Run"]  # в .blend сразу можно нажать Play
        bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 21
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "monster.blend"))
        print("THE NEST: monster_rig.fbx, анимации и monster.blend готовы")


main()
