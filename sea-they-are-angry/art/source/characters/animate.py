"""The characters' animation clips, authored in code and baked into their GLBs.

Imported by build_characters.py: export() calls build(name, rig) and the clips go out
in the GLB with the skeleton (CharacterRig plays them in the game).

The method follows Forged in Formation's crouch solver (Formnation,
Art/Characters/crouch_solver.py and build_human_anims.py): poses are solved, not
eased between by eye. Every frame is worked out in full and keyed. Feet are placed on the
ground by two-bone IK on the true hip-knee-ankle joints, with the knee driven along an
explicit pole, so a foot on the ground stays exactly where it is put. Only keyframing
every frame keeps contacts planted: FK interpolation between a few solved poses lets a
foot or a hand slide in between.

The walk and run are in place: a foot on the ground goes back at the clip's speed, and
the game plays the clip at the speed the character is really moving, so feet don't skate.
The locomotion cycles are normalised to one second (frame 0 is the left heel striking,
frame 30 is the same pose again) so the game can blend walk, run and sprint in step; the
real period and speed of each is written to the character's .anims.json.

Blender space: Z up, the character faces -Y, its left is +X. Angles below are degrees.
`body_q(pitch, roll, yaw)`: pitch + tips the top of a bone forward (so a hanging arm with
pitch - swings forward), roll + leans it to the character's left, yaw + turns it left.
"""

import json
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FWD = Vector((0, -1, 0))
CYCLE_FRAMES = 30
# A stagger slides the character over this long (the game uses the same figure).
STAGGER_SLIDE = 0.45
THROW_RELEASE = 0.32


def rad(d):
    return math.radians(d)


def body_q(pitch=0.0, roll=0.0, yaw=0.0):
    return Quaternion(Z, rad(yaw)) @ Quaternion(Y, rad(roll)) @ Quaternion(X, rad(pitch))


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def frame(d, toward):
    """An orthonormal frame: x along d, y the part of `toward` square to it."""
    x = Vector(d).normalized()
    y = Vector(toward) - x * Vector(toward).dot(x)
    if y.length < 1e-6:
        y = Z - x * x.z if abs(x.z) < 0.9 else Y - x * x.y
    y.normalize()
    return Matrix((x, y, x.cross(y))).transposed()


def two_bone(hip, end, l1, l2, pole):
    """The middle joint for a reach from hip to end, bent toward pole."""
    d = end - hip
    dist = max(1e-4, min(d.length, (l1 + l2) * 0.9995))
    dirn = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    side = Vector(pole) - dirn * Vector(pole).dot(dirn)
    if side.length < 1e-6:
        side = Z - dirn * dirn.z
    side.normalize()
    return hip + dirn * a + side * h


def bez(p0, p1, p2, p3, u):
    v = 1.0 - u
    return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u)


# ---------------------------------------------------------------- the skeleton, in maths

class Skel:
    """Forward kinematics on the rig's rest pose, so poses can be solved without Blender
    re-evaluating the scene. L[bone] is the bone's turn from rest relative to its parent
    (in armature space); W[bone] the accumulated turn; H[bone] where its head is."""

    def __init__(self, rig):
        self.rig = rig
        bones = rig.data.bones
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.h0 = {b.name: b.head_local.copy() for b in bones}
        self.t0 = {b.name: b.tail_local.copy() for b in bones}
        self.r0 = {b.name: b.matrix_local.to_quaternion() for b in bones}
        self.order = []
        left = [b.name for b in bones]
        while left:
            for n in list(left):
                if self.parent[n] is None or self.parent[n] in self.order:
                    self.order.append(n)
                    left.remove(n)
        self.root = self.order[0]
        self.reset()

    def has(self, n):
        return n in self.h0

    def reset(self):
        self.L = {n: Quaternion() for n in self.order}
        self.off = Vector()
        self.fk()

    def fk(self):
        self.W, self.H = {}, {}
        for n in self.order:
            p = self.parent[n]
            if p is None:
                self.W[n] = self.L[n].copy()
                self.H[n] = self.h0[n] + self.off
            else:
                self.W[n] = self.W[p] @ self.L[n]
                self.H[n] = self.H[p] + self.W[p] @ (self.h0[n] - self.h0[p])

    def tail(self, n):
        return self.H[n] + self.W[n] @ (self.t0[n] - self.h0[n])

    def set_world(self, n, q):
        p = self.parent[n]
        self.L[n] = (self.W[p].inverted() @ q) if p else q.copy()
        self.fk()

    def turn(self, n, pitch=0.0, roll=0.0, yaw=0.0):
        """Turn a bone by body_q in its parent's (posed) frame."""
        if n not in self.L:
            return
        self.L[n] = body_q(pitch, roll, yaw) @ self.L[n]
        self.fk()

    def turn_axis(self, n, axis, deg):
        """Turn a bone about an axis given in its parent's (posed) frame."""
        if n in self.L:
            self.L[n] = Quaternion(Vector(axis).normalized(), rad(deg)) @ self.L[n]
            self.fk()

    def place_root(self, pos=None, q=None):
        """The root bone (hips): its head at `pos` (armature space), turned by q."""
        if q is not None:
            self.L[self.root] = q
        if pos is not None:
            self.off = Vector(pos) - self.h0[self.root]
        self.fk()

    def point(self, n, d, pole, pole0):
        """Point bone n head->tail along d, twisting it so pole0 (rest) goes to pole."""
        q = (frame(d, pole) @ frame(self.t0[n] - self.h0[n], pole0).inverted()).to_quaternion()
        self.set_world(n, q)

    def limb(self, upper, lower, end, target, pole, pole0):
        """Two-bone IK: the end joint (end bone's head) to target, bending toward pole."""
        hp = self.H[upper]
        a0, b0, c0 = self.h0[upper], self.h0[lower], self.h0[end]
        l1, l2 = (b0 - a0).length, (c0 - b0).length
        k = two_bone(hp, Vector(target), l1, l2, pole)
        self.set_world(upper, (frame(k - hp, pole) @ frame(b0 - a0, pole0).inverted()).to_quaternion())
        self.set_world(lower, (frame(Vector(target) - k, pole) @ frame(c0 - b0, pole0).inverted()).to_quaternion())
        return (Vector(target) - hp).length - (l1 + l2)

    def local_rotations(self):
        """Pose-bone rotations (each in its own rest frame) and the root's location."""
        out = {}
        for n in self.order:
            r = self.r0[n]
            out[n] = r.inverted() @ self.L[n] @ r
        loc = self.r0[self.root].inverted() @ self.off
        return out, loc


# ---------------------------------------------------------------- writing actions

class Clip:
    """Collects one solved pose per frame and writes them as an action."""

    def __init__(self, sk, name, frames):
        self.sk, self.name, self.frames = sk, name, frames
        self.rot = {n: [] for n in sk.order}
        self.loc = []
        self.worst_reach = -1.0

    def grab(self):
        rots, loc = self.sk.local_rotations()
        for n, q in rots.items():
            seq = self.rot[n]
            if seq and seq[-1].dot(q) < 0.0:
                q = -q
            seq.append(q)
        self.loc.append(loc)

    def write(self):
        rig = self.sk.rig
        act = bpy.data.actions.new(self.name)
        act.use_fake_user = True
        n = len(self.loc)

        def curve(path, idx, group, values):
            fc = act.fcurves.new(path, index=idx, action_group=group)
            fc.keyframe_points.add(n)
            co = []
            for f, v in enumerate(values):
                co += [float(f), float(v)]
            fc.keyframe_points.foreach_set("co", co)
            for k in fc.keyframe_points:
                k.interpolation = 'LINEAR'
            fc.update()

        for b in self.sk.order:
            path = f'pose.bones["{b}"].rotation_quaternion'
            for i in range(4):
                curve(path, i, b, [q[i] for q in self.rot[b]])
        r = self.sk.root
        for i in range(3):
            curve(f'pose.bones["{r}"].location', i, r, [v[i] for v in self.loc])
        act.frame_range = (0, n - 1)
        # NLA strips so the glTF exporter sees every action as the rig's.
        if rig.animation_data is None:
            rig.animation_data_create()
        tr = rig.animation_data.nla_tracks.new()
        tr.name = self.name
        tr.strips.new(self.name, 0, act)
        tr.mute = True
        return act


def record(sk, name, seconds, pose_at, loop=False, frames=None):
    """Solve pose_at(t) for t in 0..1 on every frame and keep it as a clip."""
    n = frames if frames is not None else max(2, round(seconds * FPS))
    clip = Clip(sk, name, n)
    for f in range(n + 1):
        t = f / n
        sk.reset()
        r = pose_at(t)
        if isinstance(r, (int, float)):
            clip.worst_reach = max(clip.worst_reach, r)
        clip.grab()
    clip.write()
    over = f"  (a limb overreaches by {clip.worst_reach * 100:.1f} cm)" if clip.worst_reach > 0.005 else ""
    print(f"CLIP {sk.rig.name} {name}: {n + 1} frames{over}")
    return clip


# ---------------------------------------------------------------- keyed parameters

def keyed(keys, t):
    """Interpolate a list of (time, {param: value}) keys at time t: a cubic through the
    keys (Catmull-Rom tangents, flat at the ends), so motion flows through them. Values
    are floats or tuples. A key's missing params carry over from the one before."""
    full = []
    last = {}
    for kt, d in keys:
        last = dict(last)
        last.update(d)
        full.append((kt, last))
    if t <= full[0][0]:
        return dict(full[0][1])
    if t >= full[-1][0]:
        return dict(full[-1][1])
    i = 0
    while full[i + 1][0] < t:
        i += 1
    t0, a = full[i]
    t1, b = full[i + 1]
    u = (t - t0) / (t1 - t0)
    pa = full[i - 1] if i > 0 else None
    nb = full[i + 2] if i + 2 < len(full) else None
    out = {}
    for k in b:
        va, vb = a.get(k, b[k]), b[k]
        tup = isinstance(vb, (tuple, list, Vector))
        A = Vector(va) if tup else va
        Bv = Vector(vb) if tup else vb
        dt = t1 - t0
        if pa is not None and k in pa[1]:
            P = Vector(pa[1][k]) if tup else pa[1][k]
            m0 = (Bv - P) * (dt / (t1 - pa[0]))
        else:
            m0 = (Bv - A) * 0.0
        if nb is not None and k in nb[1]:
            N = Vector(nb[1][k]) if tup else nb[1][k]
            m1 = (N - A) * (dt / (nb[0] - t0))
        else:
            m1 = (Bv - A) * 0.0
        h00 = 2 * u ** 3 - 3 * u ** 2 + 1
        h10 = u ** 3 - 2 * u ** 2 + u
        h01 = -2 * u ** 3 + 3 * u ** 2
        h11 = u ** 3 - u ** 2
        out[k] = A * h00 + m0 * h10 + Bv * h01 + m1 * h11
    return out


# ---------------------------------------------------------------- the humanoid body

SIDES = (("L", 1.0), ("R", -1.0))


class Body:
    """Helpers for the humanoid rig (HUMANOID_BONES in build_characters.py)."""

    def __init__(self, sk):
        self.sk = sk
        h = sk.h0
        self.hips0 = h["hips"].copy()
        self.leg_len = (h["shin.L"] - h["thigh.L"]).length + (h["foot.L"] - h["shin.L"]).length
        self.hip_z = h["thigh.L"].z
        self.ankle0 = {s: h["foot." + s].copy() for s, _ in SIDES}
        self.toe0 = {s: sk.t0["foot." + s].copy() for s, _ in SIDES}
        self.sole = 0.0
        foot_len = (self.toe0["L"] - self.ankle0["L"]).length
        # Ground pivots for rolling the foot: under the heel and under the ball.
        self.heel0 = {s: Vector((self.ankle0[s].x, self.ankle0[s].y + 0.35 * foot_len, self.sole)) for s, _ in SIDES}
        self.ball0 = {s: Vector((self.toe0[s].x, self.toe0[s].y + 0.25 * foot_len, self.sole)) for s, _ in SIDES}
        self.shoulder0 = {s: h["upper_arm." + s].copy() for s, _ in SIDES}
        self.arm_len = (h["forearm.L"] - h["upper_arm.L"]).length + (h["hand.L"] - h["forearm.L"]).length

    # ---- trunk ----
    def hips(self, pos=(0, 0, 0), pitch=0.0, roll=0.0, yaw=0.0, absolute=False):
        p = Vector(pos) if absolute else self.hips0 + Vector(pos)
        self.sk.place_root(p, body_q(pitch, roll, yaw))

    def trunk(self, spine=(0, 0, 0), chest=(0, 0, 0), neck=(0, 0, 0), head=(0, 0, 0)):
        for b, e in (("spine", spine), ("chest", chest), ("neck", neck), ("head", head)):
            if any(e):
                self.sk.turn(b, *e)

    def look(self, pitch=0.0, roll=0.0, yaw=0.0, amount=1.0, neck_share=0.4):
        """Turn the head so it faces a world direction (pitch + looks down), the neck
        taking some of it: the head stays steady while the body moves under it."""
        sk = self.sk
        want = body_q(pitch, roll, yaw)
        have = sk.W["head"]
        fix = Quaternion().slerp(want @ have.inverted(), amount)
        n = Quaternion().slerp(fix, neck_share)
        sk.set_world("neck", n @ sk.W["neck"])
        sk.set_world("head", want if amount >= 1.0 else fix @ have)

    # ---- legs ----
    def foot_pose(self, s, pivot, pitch, yaw=0.0, roll=0.0, at=Vector()):
        """Where the ankle goes and how the foot turns when it rocks on a pivot
        ('heel', 'ball' or 'flat') by pitch (- toes up), shifted by `at` along the ground."""
        q = body_q(pitch, roll, yaw)
        a0 = self.ankle0[s]
        if pivot == "heel":
            p0 = self.heel0[s]
        elif pivot == "ball":
            p0 = self.ball0[s]
        else:
            p0 = a0
        return p0 + Vector(at) + q @ (a0 - p0), q

    def leg(self, s, ankle, foot_q, pole=None):
        sk = self.sk
        sx = 1.0 if s == "L" else -1.0
        if pole is None:
            pole = sk.W["hips"] @ Vector((sx * 0.12, -1.0, 0.0))
        over = sk.limb("thigh." + s, "shin." + s, "foot." + s, ankle, pole, FWD)
        sk.set_world("foot." + s, foot_q)
        return over

    def stand_feet(self, spread=0.0, turn_out=6.0):
        over = -1.0
        for s, sx in SIDES:
            a, q = self.foot_pose(s, "flat", 0.0, yaw=sx * turn_out, at=Vector((sx * spread, 0, 0)))
            over = max(over, self.leg(s, a, q))
        return over

    # ---- arms ----
    def arm_swing(self, s, swing=0.0, out=8.0, elbow=15.0, twist=0.0):
        """Arm hanging from the shoulder: swing + forward, out + away from the body,
        elbow + bends the forearm forward, twist + turns it in (the forearm across)."""
        sx = 1.0 if s == "L" else -1.0
        self.sk.turn("upper_arm." + s, -swing, -sx * out, -sx * twist)
        self.sk.turn("forearm." + s, -elbow, 0.0, 0.0)

    def arm_to(self, s, wrist, pole=None):
        sx = 1.0 if s == "L" else -1.0
        if pole is None:
            pole = self.sk.W["chest"] @ Vector((sx * 0.6, 1.0, -0.2))
        return self.sk.limb("upper_arm." + s, "forearm." + s, "hand." + s, Vector(wrist), pole, Vector((sx * 0.3, 1.0, 0.0)))

    def hand_world(self, s, q):
        self.sk.set_world("hand." + s, q)

    def hand_turn(self, s, pitch=0.0, roll=0.0, yaw=0.0):
        self.sk.turn("hand." + s, pitch, roll, yaw)

    def tool(self, s, direction, up=Z):
        """Turn the hand so a tool held in it (built pointing forward, the game's
        attach_aligned) points along `direction`."""
        q = (frame(direction, up) @ frame(FWD, Z).inverted()).to_quaternion()
        self.sk.set_world("hand." + s, q)

    def shoulder(self, s):
        return self.sk.H["upper_arm." + s]


# ---------------------------------------------------------------- gaits

class Gait:
    """A walk or run cycle. t 0..1, the left heel strikes at 0 and the right at 0.5.
    Distances are in leg lengths, so every body gets steps that fit its legs."""

    def __init__(self, body, period, stance, step, drop, bob, lift, strike=14.0, toe_off=30.0,
                 heel=0.12, toe=0.55, runner=False, sway=0.02, list_=3.0, yaw=5.0, lean=3.0,
                 width=0.0, swing_peak=0.4, kick=0.0, drag=None):
        self.b = body
        L = body.leg_len
        self.period, self.stance = period, stance
        # Stance travel: how far a planted foot goes back while it's down.
        self.travel = step * L
        self.speed = self.travel / (period * stance)
        self.drop, self.bob, self.lift = drop * L, bob * L, lift * L
        self.strike, self.toe_off, self.heel, self.toe = strike, toe_off, heel, toe
        self.runner, self.sway, self.list, self.yaw, self.lean = runner, sway * L, list_, yaw, lean
        self.width, self.swing_peak, self.kick = width * L, swing_peak, kick * L
        # A dragging leg: {"side": "R", "lift": fraction of lift, "toe": toe-down angle}.
        self.drag = drag or {}

    def stance_foot(self, s, u):
        """u 0..1 through the stance: the ankle and the foot's turn."""
        y = -self.travel / 2 + self.travel * u
        sx = 1.0 if s == "L" else -1.0
        at = Vector((sx * self.width, y, 0.0))
        if u < self.heel:
            k = 1.0 - ease(u / self.heel)
            return self.b.foot_pose(s, "heel", -self.strike * k, yaw=sx * 5.0, at=at)
        if u > self.toe:
            k = ease((u - self.toe) / (1.0 - self.toe))
            return self.b.foot_pose(s, "ball", self.toe_off * k, yaw=sx * 5.0, at=at)
        return self.b.foot_pose(s, "flat", 0.0, yaw=sx * 5.0, at=at)

    def foot(self, s, t):
        if t < self.stance:
            return self.stance_foot(s, t / self.stance)
        u = (t - self.stance) / (1.0 - self.stance)
        a_off, q_off = self.stance_foot(s, 1.0)
        a_on, q_on = self.stance_foot(s, 0.0)
        sx = 1.0 if s == "L" else -1.0
        lift = self.lift
        toe_down = 0.0
        if self.drag.get("side") == s:
            lift *= self.drag.get("lift", 0.3)
            toe_down = self.drag.get("toe", 15.0)
        # The swing path: up behind (a runner's heel kicks toward the seat), forward,
        # down onto the next strike.
        p0 = a_off
        p3 = a_on
        p1 = p0 + Vector((0.0, self.kick * 0.6, lift * 0.9 + self.kick))
        p2 = p3 + Vector((0.0, self.travel * 0.12 * (0.3 if self.runner else -0.2), lift * 0.75))
        w = ease(u) * 0.7 + u * 0.3
        a = bez(p0, p1, p2, p3, w)
        a.x = lerp(p0.x, p3.x, u) + sx * 0.01 * math.sin(math.pi * u)
        pitch_off = self.toe_off
        pitch_on = -self.strike
        mid = -8.0 + toe_down
        if u < 0.5:
            pitch = lerp(pitch_off, mid, ease(u / 0.5))
        else:
            pitch = lerp(mid, pitch_on, ease((u - 0.5) / 0.5))
        return a, body_q(pitch, 0.0, sx * 5.0)

    def pelvis(self, t, extra_lean=0.0):
        """The hips through the cycle: bob, sway toward the standing leg, list and twist."""
        mid_l = self.stance / 2.0
        c = math.cos(4 * math.pi * (t - mid_l))
        z = -self.drop + (-self.bob * c if self.runner else self.bob * c)
        side = math.cos(2 * math.pi * (t - mid_l))
        x = self.sway * side
        yaw = -self.yaw * math.cos(2 * math.pi * t)
        roll = -self.list * side
        return (x, 0.0, z), self.lean + extra_lean, roll, yaw

    def legs(self, t):
        over = -1.0
        for s, ph in (("L", 0.0), ("R", 0.5)):
            a, q = self.foot(s, (t + 1.0 - ph) % 1.0 if ph else t)
            over = max(over, self.b.leg(s, a, q))
        return over


def arm_phase(t):
    """+1 when the left arm is fully forward (the right leg forward, t 0.5)."""
    return -math.cos(2 * math.pi * t)


# ---------------------------------------------------------------- the keepers

KEEPER_LOOK = 2.0


def keeper_carry(b, t=0.0, swing=0.0, sway=0.0):
    """The keeper's hands: the boathook in the right, carried pointing forward and up;
    the lantern hanging from the left, a little forward of the hip."""
    b.arm_swing("R", 10.0 - 8.0 * swing, 2.0, 52.0 + 6.0 * swing, twist=8.0)
    b.tool("R", body_q(-16.0 - 4.0 * swing, 0.0, 6.0) @ FWD)
    b.arm_swing("L", 6.0 + 9.0 * swing, 4.0, 28.0 + 8.0 * swing, twist=6.0)
    # The lantern hangs plumb, swinging a little behind the arm.
    b.hand_world("L", body_q(sway, 0.0, 0.0))


def keeper_idle(b):
    def pose(t):
        w = math.sin(2 * math.pi * t)
        w2 = math.sin(4 * math.pi * t + 0.6)
        breath = math.sin(2 * math.pi * t * 2.0)
        b.hips((0.012 * w, 0.0, -0.012 - 0.004 * w2), pitch=2.0, roll=-1.5 * w, yaw=2.0 * w)
        over = b.stand_feet(0.01)
        b.trunk(spine=(1.0 + 0.6 * breath, 1.0 * w, -1.0 * w), chest=(-0.5 - 1.2 * breath, 0.6 * w, -1.0 * w))
        keeper_carry(b, t, 0.0, 2.0 * w)
        b.look(4.0 + 2.0 * w2, 0.0, 8.0 * math.sin(2 * math.pi * t + 1.0), amount=0.85)
        return over
    return pose


def keeper_cycle(b, g, arms=1.0, chest_twist=6.0, head_pitch=4.0, run=False):
    def pose(t):
        pos, lean, roll, yaw = g.pelvis(t)
        b.hips(pos, pitch=lean, roll=roll, yaw=yaw)
        over = g.legs(t)
        a = arm_phase(t)
        tw = chest_twist * math.cos(2 * math.pi * t)
        b.trunk(spine=(lean * 0.3, -roll * 0.5, tw * 0.5), chest=(lean * 0.2, -roll * 0.4, tw * 0.6))
        if run:
            # Arms bent and pumping; the hook carried higher across the body.
            b.arm_swing("R", 18.0 - 32.0 * a * arms, 2.0, 88.0 + 10.0 * a, twist=10.0)
            b.tool("R", body_q(-30.0 + 8.0 * a, 0.0, 12.0) @ FWD)
            b.arm_swing("L", 10.0 + 30.0 * a * arms, 3.0, 70.0 + 15.0 * a, twist=8.0)
            b.hand_world("L", body_q(-12.0 * a, 0.0, 0.0))
        else:
            keeper_carry(b, t, a * arms, -7.0 * math.sin(2 * math.pi * t))
        b.look(head_pitch, 0.0, 0.0, amount=0.9)
        return over
    return pose


def keeper_swing(b):
    """The boathook: wound back over the right shoulder, chopped across and down in
    front, followed through to the left, and back to the carry. 0.55 s; the blow lands
    at about 0.15 s (the game deals it on the click)."""
    keys = [
        (0.00, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": (-0.2, -0.85, 0.5), "lf": 0.0}),
        (0.08, {"lean": -4.0, "twist": -32.0, "wrist": (-0.36, 0.02, 1.42), "dir": (-0.35, 0.35, 0.87), "lf": 0.3}),
        (0.18, {"lean": 12.0, "twist": 18.0, "wrist": (-0.08, -0.52, 1.02), "dir": (0.25, -0.9, -0.25), "lf": 1.0}),
        (0.30, {"lean": 14.0, "twist": 34.0, "wrist": (0.18, -0.42, 0.78), "dir": (0.75, -0.55, -0.35), "lf": 0.8}),
        (0.55, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": (-0.2, -0.85, 0.5), "lf": 0.0}),
    ]
    return keyed_upper(b, keys, 0.55)


def keyed_upper(b, keys, seconds, legs=None):
    """Arm-led actions on a standing body: the right hand to a wrist point (scaled to the
    body), the tool along a direction, the trunk turning into it."""
    sh = b.shoulder0["R"]
    scale = b.hips0.z / 0.84

    def pose(t):
        k = keyed(keys, t * seconds)
        b.hips((0.0, 0.01 * k.get("lf", 0.0), -0.03 * k.get("lf", 0.0)), pitch=k["lean"] * 0.3, yaw=k["twist"] * 0.25)
        over = b.stand_feet(0.03) if legs is None else legs(t)
        b.trunk(spine=(k["lean"] * 0.4, 0.0, k["twist"] * 0.35), chest=(k["lean"] * 0.3, 0.0, k["twist"] * 0.4))
        w = Vector(k["wrist"])
        target = Vector((w.x * scale, w.y * scale, w.z * scale))
        b.arm_to("R", target, pole=b.sk.W["chest"] @ Vector((-0.8, 0.6, -0.3)))
        b.tool("R", Vector(k["dir"]))
        # The lantern arm goes out for balance as the blow comes round.
        lf = k.get("lf", 0.0)
        b.arm_swing("L", 10.0 + 10.0 * lf, 14.0 + 16.0 * lf, 35.0 + 20.0 * lf)
        b.hand_world("L", body_q(-6.0 * lf, 0.0, 0.0))
        b.look(6.0, 0.0, -k["twist"] * 0.4, amount=0.7)
        return over
    return pose


def keeper_hammer(b):
    """One hammer blow (the game loops it): raised high over the right shoulder, brought
    down hard to land at 65% of the cycle, a small rebound. The keeper stands square to
    the work, knees bent, the left hand steadying it."""
    scale = b.hips0.z / 0.84
    keys = [
        (0.00, {"w": (-0.2, -0.4, 0.9), "d": (0.0, -0.6, -0.8), "lean": 16.0}),
        (0.30, {"w": (-0.24, -0.18, 1.32), "d": (-0.1, 0.25, 0.97), "lean": 6.0}),
        (0.55, {"w": (-0.24, -0.12, 1.42), "d": (-0.1, 0.55, 0.83), "lean": 4.0}),
        (0.65, {"w": (-0.18, -0.5, 0.82), "d": (0.0, -0.55, -0.83), "lean": 20.0}),
        (0.78, {"w": (-0.19, -0.47, 0.86), "d": (0.0, -0.75, -0.66), "lean": 18.0}),
        (1.00, {"w": (-0.2, -0.4, 0.9), "d": (0.0, -0.6, -0.8), "lean": 16.0}),
    ]

    def pose(t):
        k = keyed(keys, t)
        b.hips((0.0, 0.03, -0.08), pitch=k["lean"] * 0.4)
        over = 0.0
        for s, sx in SIDES:
            a, q = b.foot_pose(s, "flat", 0.0, yaw=sx * 10.0, at=Vector((sx * 0.06, (-0.08 if s == "L" else 0.1), 0.0)))
            over = max(over, b.leg(s, a, q))
        b.trunk(spine=(k["lean"] * 0.4, 0.0, -4.0), chest=(k["lean"] * 0.3, 0.0, -4.0))
        w = Vector(k["w"]) * scale
        b.arm_to("R", w, pole=b.sk.W["chest"] @ Vector((-0.8, 0.4, -0.4)))
        b.tool("R", Vector(k["d"]))
        b.arm_to("L", Vector((0.18, -0.48, 0.92)) * scale, pole=b.sk.W["chest"] @ Vector((0.9, 0.3, -0.4)))
        b.hand_turn("L", 30.0, 0.0, 0.0)
        b.look(30.0, 0.0, 0.0, amount=0.8)
        return over
    return pose


def keeper_pour(b):
    """The oil can: lifted to the lamp's filler at chest height, tipped, held while it
    glugs, and lowered. 0.9 s (the game's POUR_TIME), then held."""
    scale = b.hips0.z / 0.84
    keys = [
        (0.00, {"w": (-0.24, -0.2, 0.9), "tip": 0.0, "lean": 3.0}),
        (0.25, {"w": (-0.12, -0.45, 1.18), "tip": 10.0, "lean": 8.0}),
        (0.45, {"w": (-0.06, -0.5, 1.2), "tip": 70.0, "lean": 10.0}),
        (0.85, {"w": (-0.05, -0.5, 1.19), "tip": 80.0, "lean": 10.0}),
        (1.00, {"w": (-0.06, -0.5, 1.2), "tip": 75.0, "lean": 10.0}),
    ]

    def pose(t):
        k = keyed(keys, t * 0.9)
        b.hips((0.0, 0.0, -0.02), pitch=k["lean"] * 0.3)
        over = b.stand_feet(0.03)
        b.trunk(spine=(k["lean"] * 0.4, 0.0, 6.0), chest=(k["lean"] * 0.3, 0.0, 6.0))
        b.arm_to("R", Vector(k["w"]) * scale, pole=b.sk.W["chest"] @ Vector((-0.9, 0.3, -0.3)))
        b.tool("R", body_q(0.0, 0.0, 10.0) @ FWD, up=body_q(0.0, -k["tip"], 0.0) @ Z)
        # The left hand comes under the can to steady it.
        b.arm_to("L", Vector((0.0, -0.42, 1.08)) * scale, pole=b.sk.W["chest"] @ Vector((0.9, 0.3, -0.4)))
        b.hand_turn("L", -40.0, 0.0, -30.0)
        b.look(14.0, 0.0, -6.0, amount=0.8)
        return over
    return pose


def keeper_climb(b):
    """Up a ladder in front: hands on the rails, feet on the rungs, the right hand and
    left foot climbing together and then the other pair. In place: one cycle lifts the
    keeper two rungs (CLIMB_RISE), so the game plays it at climb speed / that."""
    rung = 0.3
    rise = 2 * rung
    lad = -0.36   # the ladder's face, in front of the hips (y)
    sh = b.shoulder0

    def limb_path(t, phase, base_z, x, reach):
        """A hand or foot: on a rung going down at climb speed for 70% of the cycle, then
        lifted to the rung two above."""
        u = (t - phase) % 1.0
        if u < 0.7:
            z = base_z + rise * 0.5 - rise * (u / 0.7)
            return Vector((x, lad, z)), True
        v = (u - 0.7) / 0.3
        z = lerp(base_z - rise * 0.5, base_z + rise * 0.5, ease(v))
        return Vector((x, lad + reach * math.sin(math.pi * v), z)), False

    def pose(t):
        bobz = 0.02 * math.cos(4 * math.pi * t)
        b.hips((0.0, 0.04, -0.06 + bobz), pitch=8.0, roll=3.0 * math.sin(2 * math.pi * t))
        over = 0.0
        for s, sx, ph in (("L", 1.0, 0.5), ("R", -1.0, 0.0)):
            hand, _ = limb_path(t, ph, sh[s].z + 0.06, sx * (sh[s].x * 0.9), 0.1)
            over = max(over, b.arm_to(s, hand, pole=b.sk.W["chest"] @ Vector((sx * 1.0, 0.4, -0.6))))
            b.hand_turn(s, -50.0, 0.0, 0.0)
        for s, sx, ph in (("L", 1.0, 0.0), ("R", -1.0, 0.5)):
            p, planted = limb_path(t, ph, 0.32, sx * 0.1, 0.14)
            p.y = lad + 0.12 + (0.0 if planted else p.y - lad)
            q = body_q(0.0 if planted else -15.0, 0.0, sx * 8.0)
            over = max(over, b.leg(s, p, q, pole=b.sk.W["hips"] @ Vector((sx * 0.3, -1.0, 0.3))))
        b.trunk(spine=(4.0, 0.0, 0.0), chest=(2.0, 0.0, 0.0))
        b.look(-12.0, 0.0, 0.0, amount=0.7)
        return over
    return pose, rise


def keeper_flare(b):
    """Firing the flare gun: the right arm up and out toward the target, a kick of
    recoil, and down. 0.6 s."""
    keys = [
        (0.00, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": (-0.2, -0.85, 0.5), "lf": 0.0}),
        (0.14, {"lean": -6.0, "twist": -8.0, "wrist": (-0.2, -0.55, 1.55), "dir": (-0.1, -0.7, 0.7), "lf": 0.4}),
        (0.20, {"lean": -9.0, "twist": -10.0, "wrist": (-0.22, -0.45, 1.68), "dir": (-0.1, -0.5, 0.86), "lf": 0.5}),
        (0.38, {"lean": -6.0, "twist": -8.0, "wrist": (-0.2, -0.55, 1.55), "dir": (-0.1, -0.7, 0.7), "lf": 0.4}),
        (0.60, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": (-0.2, -0.85, 0.5), "lf": 0.0}),
    ]
    return keyed_upper(b, keys, 0.6)


def hit_react(b, carry=None, scale_t=1.0):
    """A blow that doesn't floor: the chest snaps back, the head down and away, the arms
    jerk up; 0.45 s."""
    keys = [(0.0, {"p": 0.0, "r": 0.0, "a": 0.0}), (0.07, {"p": -14.0, "r": 6.0, "a": 1.0}),
            (0.2, {"p": -8.0, "r": 3.0, "a": 0.6}), (0.45, {"p": 0.0, "r": 0.0, "a": 0.0})]

    def pose(t):
        k = keyed(keys, t * 0.45)
        b.hips((0.0, 0.03 * k["a"], -0.02 * k["a"]), pitch=k["p"] * 0.3)
        over = b.stand_feet(0.02)
        b.trunk(spine=(k["p"] * 0.4, k["r"], 0.0), chest=(k["p"] * 0.6, k["r"], 4.0 * k["a"]))
        if carry:
            carry(b, k["a"])
        else:
            for s, _ in SIDES:
                b.arm_swing(s, 25.0 * k["a"], 10.0 + 12.0 * k["a"], 20.0 + 50.0 * k["a"])
        b.look(14.0 * k["a"], -8.0 * k["a"], 10.0 * k["a"], amount=0.6)
        return over
    return pose


def stagger(b, back=True, travel=0.5, seconds=0.8, carry=None, heavy=0.0):
    """Knocked off balance by a blow: the body snaps away from it, a foot steps to catch
    the weight, the arms fly out, and it recovers. The game slides the character
    `travel` metres (back, or forward if hit from behind) over STAGGER_SLIDE seconds,
    eased out; the planted feet are keyed against that slide, so they stay put."""
    sgn = 1.0 if back else -1.0      # +Y is behind the character
    slide = STAGGER_SLIDE
    keys = [(0.0, {"p": 0.0, "a": 0.0}), (0.07, {"p": 1.0, "a": 1.0}), (0.25, {"p": 0.75, "a": 0.85}),
            (0.5, {"p": 0.3, "a": 0.4}), (seconds, {"p": 0.0, "a": 0.0})]
    y0 = {s: b.ankle0[s].y for s, _ in SIDES}

    def d(tt):
        u = min(1.0, tt / slide)
        return travel * (1.0 - (1.0 - u) ** 2) * sgn

    # Which foot catches the fall: the right steps first, then the left rejoins it.
    step_r = (0.08, 0.3, 0.16 * sgn)
    step_l = (0.32, 0.55, 0.02 * sgn)

    def foot(s, tt, step):
        t0, t1, land = step
        if tt < t0:
            return -d(tt), 0.0, 0.0
        if tt < t1:
            u = (tt - t0) / (t1 - t0)
            y = lerp(-d(t0), land, ease(u))
            return y, 0.07 * math.sin(math.pi * u), -12.0 * math.sin(math.pi * u)
        return land - (d(tt) - d(t1)), 0.0, 0.0

    def pose(t):
        tt = t * seconds
        k = keyed(keys, tt)
        p, a = k["p"], k["a"]
        b.hips((0.0, 0.0, -0.05 * a - 0.03 * heavy * a), pitch=-8.0 * sgn * p, roll=3.0 * p)
        over = 0.0
        for s, sx in SIDES:
            y, lift, pitch = foot(s, tt, step_r if s == "R" else step_l)
            a_, q = b.foot_pose(s, "flat", pitch, yaw=sx * 8.0, at=Vector((sx * 0.03, y, lift)))
            over = max(over, b.leg(s, a_, q))
        b.trunk(spine=(-12.0 * sgn * p, 4.0 * p, 0.0), chest=(-10.0 * sgn * p, 3.0 * p, 5.0 * p), neck=(14.0 * p * sgn, 0.0, 0.0))
        if carry:
            carry(b, 0.0, 0.0, 0.0)
            b.sk.turn("upper_arm.R", -30.0 * a * sgn, 18.0 * a, 0.0)
            b.sk.turn("upper_arm.L", -35.0 * a * sgn, -22.0 * a, 0.0)
        else:
            for s, _ in SIDES:
                b.arm_swing(s, 32.0 * a * sgn + 6.0, 10.0 + 28.0 * a, 20.0 + 40.0 * a)
        b.look(10.0 * p * sgn, 0.0, 0.0, amount=0.4)
        return over
    return pose


def keeper_throw(b):
    """Hurling the boathook up like a harpoon: drawn back over the shoulder, the body
    leaning away, then thrown up and forward. It leaves the hand at THROW_RELEASE."""
    up = (-0.2, -0.85, 0.5)
    keys = [
        (0.00, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": up, "lf": 0.0}),
        (0.22, {"lean": -12.0, "twist": -32.0, "wrist": (-0.3, 0.22, 1.5), "dir": (0.0, -0.45, 0.89), "lf": 0.6}),
        (0.32, {"lean": 4.0, "twist": 8.0, "wrist": (-0.18, -0.4, 1.68), "dir": (0.0, -0.45, 0.89), "lf": 1.0}),
        (0.45, {"lean": 14.0, "twist": 24.0, "wrist": (-0.04, -0.45, 1.15), "dir": (0.1, -0.9, -0.1), "lf": 0.8}),
        (0.80, {"lean": 2.0, "twist": 0.0, "wrist": (-0.27, -0.16, 0.95), "dir": up, "lf": 0.0}),
    ]
    return keyed_upper(b, keys, 0.8)


def keeper_hit_arms(b, a):
    keeper_carry(b, 0.0, 0.0, 0.0)
    b.sk.turn("upper_arm.R", -14.0 * a, -8.0 * a, 0.0)
    b.sk.turn("upper_arm.L", -18.0 * a, 10.0 * a, 0.0)


def kneel_work(b):
    """Down on the left knee beside a fallen keeper, both hands on them, pressing and
    shaking: a 0.8 s loop (holding interact to revive)."""
    scale = b.hips0.z / 0.84

    def pose(t):
        push = 0.5 - 0.5 * math.cos(2 * math.pi * t)
        hz = b.hip_z
        b.hips((0.0, 0.08, -(hz * 0.48) - 0.02 * push), pitch=22.0 + 6.0 * push)
        over = 0.0
        # Left knee down: shin flat on the ground behind; right foot planted forward.
        ak, qk = b.foot_pose("L", "flat", 55.0, at=Vector((0.03, 0.42, 0.06)))
        over = max(over, b.leg("L", ak, qk, pole=b.sk.W["hips"] @ Vector((0.1, -1.0, -0.4))))
        af, qf = b.foot_pose("R", "flat", 0.0, yaw=-8.0, at=Vector((-0.05, -0.22, 0.0)))
        over = max(over, b.leg("R", af, qf))
        b.trunk(spine=(10.0 + 4.0 * push, 0.0, 0.0), chest=(8.0 + 4.0 * push, 0.0, 0.0))
        for s, sx in SIDES:
            w = Vector((sx * 0.1, -0.42, 0.36 - 0.05 * push)) * scale
            over = max(over, b.arm_to(s, w, pole=b.sk.W["chest"] @ Vector((sx * 1.0, 0.3, 0.0))))
            b.hand_turn(s, 40.0, 0.0, 0.0)
        b.look(45.0, 0.0, 0.0, amount=0.8)
        return over
    return pose


# ---------------------------------------------------------------- getting up

def gk(hp, hr, sp=(0, 0, 0), nk=(0, 0, 0), aL=None, aR=None, fL=0.0, fR=0.0, kL=1.0, kR=1.0, wL=None, wR=None):
    """One get-up key. hp: the hips (absolute, metres) and hr their turn (pitch, roll,
    yaw); sp the spine's bend (the chest takes 60% more), nk the neck's. aL/aR: the
    ankles as (sideways from where they stand, y, z), or None to stand. fL/fR: the feet's
    pitch (+ toes down). kL/kR: which way the knees point: 1 forward, 0 up, -1 down.
    wL/wR: where a hand is planted, or None to let the arm hang."""
    return {"hp": hp, "hr": hr, "sp": sp, "nk": nk, "aL": aL, "aR": aR, "fL": fL, "fR": fR, "kL": kL, "kR": kR,
            "wL": wL, "wR": wR}


def getup_back(b, slow=1.0, heavy=0.0):
    """Off its back: head and shoulders up onto the elbows, sit up with the knees drawn
    in and the hands behind, rock forward onto the feet over a hand pushing off the
    ground, hands to the knees, and stand. Ends standing over the clip's origin; starts
    lying with its hips behind that (the game lays it there, where the ragdoll lies)."""
    hz = b.hips0.z
    L = b.leg_len
    lie_y = 0.62 * L
    sh = {s: b.shoulder0[s] for s, _ in SIDES}
    ay = b.ankle0["L"].y
    T = 1.7 * slow
    straight = lie_y - 0.04 - 0.97 * L
    keys = [
        (0.00, gk((0, lie_y, 0.13), (-88, 0, 0), (0, 0, 0), (0, 0, 0), (0.03, straight, 0.09), (-0.03, straight, 0.09),
                  -55, -60, 0, 0, (sh["L"].x + 0.06, lie_y + 0.04, 0.05), (sh["R"].x - 0.06, lie_y + 0.04, 0.05))),
        (0.22 * T, gk((0, lie_y, 0.13), (-84, 0, 0), (8, 0, 0), (28, 0, 0), (0.03, straight + 0.08, 0.09), (-0.03, straight + 0.02, 0.09),
                      -50, -55, 0, 0, (sh["L"].x + 0.08, lie_y + 0.3, 0.05), (sh["R"].x - 0.08, lie_y + 0.3, 0.05))),
        (0.48 * T, gk((0, lie_y - 0.02, 0.14), (-35, 0, 0), (8, 0, 0), (12, 0, 0), (0.06, lie_y - 0.42 * L, 0.1), (-0.06, lie_y - 0.5 * L, 0.1),
                      0, 0, 0, 0, (sh["L"].x + 0.1, lie_y + 0.26, 0.05), (sh["R"].x - 0.1, lie_y + 0.26, 0.05))),
        (0.70 * T, gk((0, 0.22 + 0.05 * heavy, 0.24 + 0.08 * heavy), (18, 0, -8), (18, 0, -6), (-6, 0, 0), (0.1, ay + 0.02, 0.1), (-0.1, ay - 0.02, 0.1),
                      0, 0, 1, 1, None, (sh["R"].x - 0.22, 0.32, 0.05))),
        (0.86 * T, gk((0, 0.08, hz * 0.66), (30, 0, -3), (14, 0, -3), (-14, 0, 0), (0.08, ay, 0.1), (-0.08, ay, 0.1),
                      0, 0, 1, 1, None, None)),
        (1.00 * T, gk((0, 0.0, hz - 0.01), (2, 0, 0))),
    ]
    return getup_pose(b, keys, T), (0.0, lie_y, 0.13), T


def getup_front(b, slow=1.0, heavy=0.0):
    """Off its front: hands under the shoulders, push the chest up, draw the left knee
    under onto all fours, plant the right foot, push off that knee with both hands and
    stand."""
    hz = b.hips0.z
    L = b.leg_len
    lie_y = 0.5 * L
    sh = {s: b.shoulder0[s] for s, _ in SIDES}
    ay = b.ankle0["L"].y
    up = sh["L"].z - hz
    T = 1.6 * slow
    back = lie_y + 0.04 + 0.97 * L
    hand_y = lie_y - up * 0.82
    kneel_hz = 0.06 + (b.sk.h0["shin.L"] - b.sk.h0["thigh.L"]).length + 0.06
    keys = [
        (0.00, gk((0, lie_y, 0.15), (88, 0, 0), (0, 0, 0), (-30, 0, 0), (0.03, back, 0.08), (-0.03, back, 0.08),
                  80, 80, -1, -1, (sh["L"].x + 0.14, hand_y, 0.04), (sh["R"].x - 0.14, hand_y, 0.04))),
        (0.26 * T, gk((0, lie_y, 0.2), (70, 0, 0), (-14, 0, 0), (-22, 0, 0), (0.03, back, 0.08), (-0.03, back, 0.08),
                      80, 80, -1, -1, (sh["L"].x + 0.12, hand_y, 0.04), (sh["R"].x - 0.12, hand_y, 0.04))),
        (0.50 * T, gk((0, lie_y * 0.7, kneel_hz + 0.03 * heavy), (55, 0, 0), (-6, 0, 0), (-25, 0, 0),
                      (0.05, lie_y * 0.7 + 0.42 * L, 0.1), (-0.05, lie_y * 0.7 + 0.45 * L, 0.1),
                      100, 100, -1, -1, (sh["L"].x + 0.06, hand_y, 0.04), (sh["R"].x - 0.06, hand_y, 0.04))),
        (0.70 * T, gk((0, lie_y * 0.55, kneel_hz + 0.08), (35, 0, 0), (6, 0, 0), (-18, 0, 0),
                      (0.05, lie_y * 0.55 + 0.45 * L, 0.1), (-0.08, ay - 0.06, 0.1),
                      100, 0, -1, 1, (0.14, -0.04, hz * 0.6), (-0.12, -0.08, hz * 0.62))),
        (0.86 * T, gk((0, 0.1, hz * 0.8), (22, 0, 0), (8, 0, 0), (-12, 0, 0), (0.06, 0.2, 0.18), (-0.07, ay - 0.03, 0.1),
                      30, 0, 1, 1, None, None)),
        (1.00 * T, gk((0, 0.0, hz - 0.01), (2, 0, 0))),
    ]
    return getup_pose(b, keys, T), (0.0, lie_y, 0.15), T


def getup_pose(b, keys, T):
    """Pose from get-up keys (gk): everything numeric is interpolated through the keys;
    the hands blend between planted (IK to the point) and hanging free."""
    def numeric(d, s_side):
        out = {"hp": d["hp"], "hr": d["hr"], "sp": d["sp"], "nk": d["nk"]}
        for s, sx in SIDES:
            a = d["a" + s]
            out["a" + s] = (0.0, b.ankle0[s].y, b.ankle0[s].z) if a is None else a
            out["f" + s] = d["f" + s]
            out["k" + s] = d["k" + s]
        return out

    nk_keys = [(kt, numeric(d, None)) for kt, d in keys]

    def planted(i, s):
        return keys[i][1]["w" + s]

    def pose(t):
        tt = t * T
        k = keyed(nk_keys, tt)
        prev = max(i for i, (kt, _) in enumerate(keys) if kt <= tt + 1e-9)
        nxt = min(prev + 1, len(keys) - 1)
        span = max(1e-6, keys[nxt][0] - keys[prev][0])
        u = ease((tt - keys[prev][0]) / span) if nxt != prev else 0.0
        b.hips(Vector(k["hp"]), *k["hr"], absolute=True)
        sp, nk = k["sp"], k["nk"]
        b.trunk(spine=tuple(sp), chest=tuple(v * 0.6 for v in sp), neck=tuple(nk))
        over = 0.0
        hips_fwd = b.sk.W["hips"] @ FWD
        for s, sx in SIDES:
            a = Vector(k["a" + s])
            ankle = Vector((b.ankle0[s].x + a.x, a.y, a.z))
            q = body_q(k["f" + s], 0.0, sx * 6.0)
            kp = max(-1.0, min(1.0, k["k" + s]))
            if kp >= 0.0:
                pole = hips_fwd * kp + Z * (1.0 - kp)
            else:
                pole = hips_fwd * (1.0 + kp) - Z * (-kp) + Y * (-kp * 0.3)
            pole = pole + Vector((sx * 0.12, 0.0, 0.0))
            over = max(over, b.leg(s, ankle, q, pole))
        base = {n: b.sk.L[n].copy() for n in b.sk.order}
        for s, sx in SIDES:
            pa, pb_ = planted(prev, s), planted(nxt, s)
            w_plant = lerp(1.0 if pa else 0.0, 1.0 if pb_ else 0.0, u)
            # The free arm: hanging, a little forward, elbow soft.
            b.sk.L["upper_arm." + s] = base["upper_arm." + s]
            b.sk.L["forearm." + s] = base["forearm." + s]
            b.sk.fk()
            b.arm_swing(s, 8.0, 10.0, 20.0)
            free = (b.sk.L["upper_arm." + s].copy(), b.sk.L["forearm." + s].copy(), b.sk.L["hand." + s].copy())
            if w_plant > 0.0:
                if pa and pb_:
                    target = Vector(pa).lerp(Vector(pb_), u)
                else:
                    target = Vector(pa or pb_)
                b.arm_to(s, target, pole=b.sk.W["chest"] @ Vector((sx * 0.7, 1.0, 0.0)))
                b.hand_turn(s, 55.0, 0.0, 0.0)
                ik = (b.sk.L["upper_arm." + s].copy(), b.sk.L["forearm." + s].copy(), b.sk.L["hand." + s].copy())
                for n, f, i in zip(("upper_arm.", "forearm.", "hand."), free, ik):
                    b.sk.L[n + s] = f.slerp(i, w_plant)
                b.sk.fk()
        return over
    return pose


# ---------------------------------------------------------------- the creatures (humanoid)

def bloated_idle(b):
    def pose(t):
        w = math.sin(2 * math.pi * t)
        breath = 0.5 - 0.5 * math.cos(2 * math.pi * t * 2.0)
        b.hips((0.02 * w, 0.0, -0.05), pitch=10.0, roll=-3.0 * w, yaw=3.0 * w)
        over = b.stand_feet(0.05, 14.0)
        b.trunk(spine=(10.0 + 3.0 * breath, 2.0 * w, 0.0), chest=(8.0 - 2.0 * breath, 2.0 * w, 0.0), neck=(18.0, -6.0 * w, 0.0))
        for s, sx in SIDES:
            b.arm_swing(s, 10.0 + 4.0 * math.sin(2 * math.pi * t + (0.0 if s == "L" else 1.5)), 14.0, 22.0)
        b.look(28.0, 10.0 * math.sin(2 * math.pi * t - 0.8), 6.0 * w, amount=0.5)
        return over
    return pose


def bloated_cycle(b, g):
    """A shambling lurch: the right leg drags, the body rolls over each step, the arms
    hang forward and swing late, the head lolls."""
    def pose(t):
        pos, lean, roll, yaw = g.pelvis(t)
        b.hips(pos, pitch=lean, roll=roll * 1.3, yaw=yaw)
        over = g.legs(t)
        a = arm_phase(t)
        b.trunk(spine=(10.0, -roll * 0.7, 4.0 * math.cos(2 * math.pi * t)), chest=(10.0, -roll * 0.6, 4.0 * math.cos(2 * math.pi * t)),
                neck=(20.0, 0.0, 0.0))
        lag = math.cos(2 * math.pi * t - 1.2)
        b.arm_swing("L", 18.0 + 10.0 * lag, 14.0, 26.0 + 6.0 * lag)
        b.arm_swing("R", 18.0 - 10.0 * lag, 14.0, 26.0 - 6.0 * lag)
        b.look(30.0, 14.0 * math.sin(2 * math.pi * t - 1.0), 0.0, amount=0.45)
        return over
    return pose


def bloated_swell(b):
    """Swelling to burst: arms spread and lift, the back arches, the head goes back,
    trembling harder and harder. 1.2 s (the game's BLOAT_TIME)."""
    def pose(t):
        k = ease(t)
        shake = math.sin(t * 1.2 * 2 * math.pi * 11.0) * (0.3 + 0.7 * k)
        b.hips((0.0, 0.0, -0.05 + 0.04 * k), pitch=10.0 - 18.0 * k, roll=2.0 * shake)
        over = b.stand_feet(0.05 + 0.04 * k, 14.0)
        b.trunk(spine=(10.0 - 20.0 * k, 0.0, 0.0), chest=(8.0 - 18.0 * k, 3.0 * shake, 0.0), neck=(18.0 - 40.0 * k, 0.0, 0.0))
        for s, sx in SIDES:
            b.arm_swing(s, 10.0 + 25.0 * k, 14.0 + 50.0 * k + 3.0 * shake, 22.0 + 20.0 * k)
        b.look(-30.0 * k, 4.0 * shake, 0.0, amount=0.6)
        return over
    return pose


def creature_strike(b, reach=1.0, slow=1.0):
    """Both arms up and clubbed down on whatever's in front (a fence, a door): 0.9 s."""
    scale = b.hips0.z / 0.84
    T = 0.9 * slow
    keys = [(0.0, {"lean": 10.0, "up": 0.0}), (0.4 * T, {"lean": -8.0, "up": 1.0}),
            (0.55 * T, {"lean": 30.0, "up": -0.4}), (0.7 * T, {"lean": 28.0, "up": -0.3}), (T, {"lean": 10.0, "up": 0.0})]

    def pose(t):
        k = keyed(keys, t * T)
        b.hips((0.0, 0.03, -0.05), pitch=k["lean"] * 0.35)
        over = b.stand_feet(0.06, 12.0)
        b.trunk(spine=(k["lean"] * 0.35, 0.0, 0.0), chest=(k["lean"] * 0.3, 0.0, 0.0), neck=(8.0, 0.0, 0.0))
        up = k["up"]
        for s, sx in SIDES:
            sh = b.shoulder(s)
            if up >= 0:
                w = sh + Vector((sx * 0.08, -0.15 * reach - 0.05 * up, b.arm_len * (0.1 + 0.75 * up)))
            else:
                w = sh + Vector((sx * 0.05, -0.55 * reach, -b.arm_len * (0.35 - up * 0.6)))
            over = max(over, b.arm_to(s, w, pole=b.sk.W["chest"] @ Vector((sx * 0.8, 0.6, -0.2))))
        b.look(20.0, 0.0, 0.0, amount=0.6)
        return over
    return pose


def burn_writhe(b):
    """Caught in the focused beam: it stops dead and writhes, arms thrown up over its
    face, head wrenched away from the light, knees buckling, the body shuddering and
    twisting from side to side. 0.9 s loop."""
    def pose(t):
        w = math.sin(2 * math.pi * t)
        shake = math.sin(2 * math.pi * t * 6.0)
        b.hips((0.012 * shake, 0.04, -0.07 - 0.015 * math.sin(4 * math.pi * t)), pitch=12.0, roll=4.0 * w, yaw=12.0 * w)
        over = b.stand_feet(0.07, 14.0)
        b.trunk(spine=(12.0 + 3.0 * shake, -5.0 * w, 14.0 * w), chest=(10.0, -4.0 * w, 16.0 * w + 3.0 * shake), neck=(20.0, 0.0, 0.0))
        for s, sx in SIDES:
            hi = 0.5 + 0.5 * math.sin(2 * math.pi * t + (0.0 if s == "L" else math.pi))
            b.arm_swing(s, 70.0 + 18.0 * hi + 3.0 * shake, 22.0, 100.0 + 25.0 * hi, twist=20.0)
        b.look(25.0, 10.0 * w, -40.0 * w, amount=0.8)
        return over
    return pose


def smotherer_idle(b):
    def pose(t):
        w = math.sin(2 * math.pi * t)
        b.hips((0.0, 0.03, -0.1), pitch=16.0, roll=-2.0 * w, yaw=4.0 * w)
        over = b.stand_feet(0.05, 10.0)
        b.trunk(spine=(14.0, 0.0, 3.0 * w), chest=(12.0 + 2.0 * math.sin(4 * math.pi * t), 0.0, 3.0 * w), neck=(-8.0, 0.0, 0.0))
        for s, sx in SIDES:
            b.arm_swing(s, 22.0 + 6.0 * math.sin(2 * math.pi * t + (0.0 if s == "L" else 2.0)), 10.0, 30.0)
            b.hand_turn(s, -20.0, 0.0, 0.0)
        b.look(0.0, 6.0 * w, 20.0 * math.sin(2 * math.pi * t * 0.5), amount=0.7)
        return over
    return pose


def smotherer_cycle(b, g):
    """A stalking creep: low and hunched, long reaching strides, the long arms carried out
    in front, hands loose, the head thrust forward and steady."""
    def pose(t):
        pos, lean, roll, yaw = g.pelvis(t)
        b.hips(pos, pitch=lean, roll=roll, yaw=yaw)
        over = g.legs(t)
        a = arm_phase(t)
        tw = 8.0 * math.cos(2 * math.pi * t)
        b.trunk(spine=(14.0, -roll * 0.5, tw * 0.5), chest=(12.0, -roll * 0.4, tw * 0.6), neck=(-10.0, 0.0, 0.0))
        b.arm_swing("L", 38.0 + 16.0 * a, 8.0, 34.0 + 10.0 * a)
        b.arm_swing("R", 38.0 - 16.0 * a, 8.0, 34.0 - 10.0 * a)
        for s, _ in SIDES:
            b.hand_turn(s, -25.0, 0.0, 0.0)
        b.look(-2.0, 0.0, 0.0, amount=0.9)
        return over
    return pose


def smotherer_climb(b):
    """Spidering up the tower: flat to the stone, arms reaching high and pulling, the
    knees out like a frog's. 1.0 s loop; the game moves it up at CLIMB_SPEED."""
    sh = b.shoulder0
    rise = 0.9
    wall = -0.3

    def limb(t, phase, base_z, x):
        u = (t - phase) % 1.0
        if u < 0.6:
            return Vector((x, wall, base_z + rise * 0.5 - rise * (u / 0.6))), True
        v = (u - 0.6) / 0.4
        return Vector((x * (1.0 + 0.2 * math.sin(math.pi * v)), wall + 0.08 * math.sin(math.pi * v),
                       lerp(base_z - rise * 0.5, base_z + rise * 0.5, ease(v)))), False

    def pose(t):
        b.hips((0.0, 0.08, -0.12 + 0.03 * math.cos(4 * math.pi * t)), pitch=-8.0, roll=6.0 * math.sin(2 * math.pi * t))
        over = 0.0
        for s, sx, ph in (("L", 1.0, 0.5), ("R", -1.0, 0.0)):
            w, _ = limb(t, ph, sh[s].z + 0.08, sx * (abs(sh[s].x) + 0.18))
            over = max(over, b.arm_to(s, w, pole=Vector((sx * 1.0, 0.2, -0.5))))
            b.hand_turn(s, -60.0, 0.0, 0.0)
        for s, sx, ph in (("L", 1.0, 0.0), ("R", -1.0, 0.5)):
            p, planted = limb(t, ph, 0.3, sx * 0.3)
            p.y += 0.1
            over = max(over, b.leg(s, p, body_q(-30.0, 0.0, sx * 30.0), pole=Vector((sx * 1.0, -0.4, 0.2))))
        b.trunk(spine=(-6.0, 0.0, 0.0), chest=(-4.0, 0.0, 0.0), neck=(-20.0, 0.0, 0.0))
        b.look(-35.0, 0.0, 0.0, amount=0.7)
        return over
    return pose, rise


def smotherer_smother(b):
    """Wrapped round the lamp gallery: arms spread round the glass, pressing in, breathing
    slowly. 2.5 s loop."""
    def pose(t):
        br = math.sin(2 * math.pi * t)
        b.hips((0.0, 0.06, -0.2), pitch=-14.0)
        over = 0.0
        for s, sx in SIDES:
            p, q = b.foot_pose(s, "ball", 35.0, yaw=sx * 25.0, at=Vector((sx * 0.12, -0.08, 0.0)))
            over = max(over, b.leg(s, p, q, pole=Vector((sx * 1.0, -0.6, 0.0))))
        b.trunk(spine=(-6.0 + 2.0 * br, 0.0, 0.0), chest=(-8.0 + 3.0 * br, 0.0, 0.0), neck=(30.0, 0.0, 0.0))
        for s, sx in SIDES:
            sh = b.shoulder(s)
            w = sh + Vector((sx * (0.45 + 0.03 * br), -0.42 - 0.02 * br, 0.15))
            over = max(over, b.arm_to(s, w, pole=Vector((sx * 0.8, 0.5, 0.3))))
            b.hand_turn(s, -20.0, 0.0, sx * -40.0)
        b.look(20.0, 0.0, 0.0, amount=0.5)
        return over
    return pose


# ---------------------------------------------------------------- crab and squid

def crab_clips(sk):
    """Six legs in two alternating tripods (front and back on one side with the middle on
    the other), tips planted by IK; the body rides level, rocking a little."""
    legs = [(i, s) for i in range(3) for s in ("L", "R")]
    tips0 = {(i, s): sk.t0[f"leg{i}.{s}.tip"].copy() for i, s in legs}
    hip0 = {(i, s): sk.h0[f"leg{i}.{s}"].copy() for i, s in legs}
    reach = (tips0[(1, "L")] - hip0[(1, "L")]).length
    travel = 0.32 * reach

    def tripod(i, s):
        return 0.0 if (i % 2 == 0) == (s == "L") else 0.5

    def pose_legs(t, travel, lift, stance=0.55):
        over = -1.0
        for i, s in legs:
            sx = 1.0 if s == "L" else -1.0
            u = (t + tripod(i, s)) % 1.0
            tip = tips0[(i, s)].copy()
            if u < stance:
                k = u / stance
                tip.y += -travel / 2 + travel * k
            else:
                k = (u - stance) / (1.0 - stance)
                tip.y += travel / 2 - travel * ease(k)
                tip.z += lift * math.sin(math.pi * k)
                tip.x += sx * 0.04 * math.sin(math.pi * k)
            pole = Vector((sx * 0.6, 0.0, 1.0))
            over = max(over, crab_leg(sk, i, s, tip, pole))
        return over

    def walk(t):
        rock = math.sin(4 * math.pi * t)
        sk.place_root(sk.h0["body"] + Vector((0.0, 0.0, 0.02 * rock)), body_q(1.5 * rock, 2.0 * math.sin(2 * math.pi * t), 0.0))
        over = pose_legs(t, travel, 0.16)
        claws(sk, t, 1.0)
        return over

    def idle(t):
        w = math.sin(2 * math.pi * t)
        sk.place_root(sk.h0["body"] + Vector((0.0, 0.0, -0.02 + 0.015 * w)), body_q(-1.0 * w, 0.0, 0.0))
        over = pose_legs(0.25, 0.0, 0.0)
        claws(sk, t, 0.35)
        return over

    def rummage(t):
        w = math.sin(2 * math.pi * t)
        sk.place_root(sk.h0["body"] + Vector((0.0, -0.04, -0.06)), body_q(8.0 + 2.0 * w, 2.0 * w, 0.0))
        over = pose_legs(0.25, 0.0, 0.0)
        # Both claws picking and tearing at what's in front, out of step.
        for side, ph, k in (("R", 0.0, 1.0), ("L", 0.4, 1.3)):
            u = math.sin(2 * math.pi * (t * 2.0 + ph))
            sk.turn(f"claw_arm.{side}", 20.0 + 18.0 * u, 0.0, (8.0 if side == "R" else -8.0) * u)
            sk.turn(f"claw.{side}", 25.0 * k * max(0.0, u), 0.0, 0.0)
        return over

    def recoil(t):
        """Struck: the front of the shell rears up, the claws fly up and back, legs braced."""
        k = keyed([(0.0, {"a": 0.0}), (0.1, {"a": 1.0}), (0.35, {"a": 0.6}), (0.7, {"a": 0.0})], t * 0.7)["a"]
        sk.place_root(sk.h0["body"] + Vector((0.0, 0.05 * k, 0.06 * k)), body_q(-12.0 * k, 4.0 * k, 0.0))
        over = pose_legs(0.25, 0.0, 0.0)
        for side in ("L", "R"):
            sx = 1.0 if side == "L" else -1.0
            sk.turn(f"claw_arm.{side}", -30.0 * k, 0.0, sx * 15.0 * k)
            sk.turn(f"claw.{side}", -20.0 * k, 0.0, 0.0)
        return over

    speed = travel / (0.55 * 0.9)
    return [("idle", 2.4, idle, True), ("walk", 0.9, walk, True), ("rummage", 0.8, rummage, True),
            ("stagger_back", 0.7, recoil, False)], {"walk": {"period": 0.9, "speed": speed}}


def crab_leg(sk, i, s, tip, pole):
    """Two-bone IK for a crab leg: hip -> knee -> tip, with the tip as the chain's end."""
    up, lo = f"leg{i}.{s}", f"leg{i}.{s}.tip"
    hp = sk.H[up]
    a0, b0, c0 = sk.h0[up], sk.h0[lo], sk.t0[lo]
    l1, l2 = (b0 - a0).length, (c0 - b0).length
    k = two_bone(hp, tip, l1, l2, pole)
    sx = 1.0 if s == "L" else -1.0
    pole0 = Vector((sx * 0.5, 0.0, 1.0))
    sk.set_world(up, (frame(k - hp, pole) @ frame(b0 - a0, pole0).inverted()).to_quaternion())
    sk.set_world(lo, (frame(tip - k, pole) @ frame(c0 - b0, pole0).inverted()).to_quaternion())
    return (tip - hp).length - (l1 + l2)


def claws(sk, t, amount):
    """The claws carried up in front, swaying, the big one a little behind the beat."""
    for side, ph in (("R", 0.0), ("L", 1.3)):
        w = math.sin(2 * math.pi * t + ph)
        sx = 1.0 if side == "L" else -1.0
        sk.turn(f"claw_arm.{side}", -6.0 + 5.0 * w * amount, 0.0, sx * 4.0 * w * amount)
        sk.turn(f"claw.{side}", 4.0 * w * amount, 0.0, 0.0)


def squid_clips(sk):
    """Crawling: the arms reach forward in two alternating sets of three, grip, and drag
    the body after them, curling as they lift; the mantle pulses with each pull."""
    arms = [i for i in range(6) if sk.has(f"arm{i}.a")]
    info = {}
    for i in arms:
        d = sk.t0[f"arm{i}.c"] - sk.h0[f"arm{i}.a"]
        flat = Vector((d.x, d.y, 0.0)).normalized()
        # Lift turns the arm up in its own vertical plane; sweep swings it round
        # toward the front (which side that is depends on which way it points).
        info[i] = {"lift": flat.cross(Z), "front": -flat.y, "side": 1.0 if flat.x >= 0 else -1.0}

    def lift(i, seg, deg):
        sk.turn_axis(f"arm{i}.{seg}", info[i]["lift"], deg)

    def sweep(i, seg, deg):
        """+ swings the arm toward the front."""
        sk.turn_axis(f"arm{i}.{seg}", Z, -info[i]["side"] * deg)

    def crawl(t):
        strokes = 3
        pulse = 0.5 - 0.5 * math.cos(2 * math.pi * t * strokes)
        sk.place_root(sk.h0["mantle"] + Vector((0.0, -0.02 * pulse, 0.015 * pulse)), body_q(-3.0 * pulse, 0.0, 0.0))
        for i in arms:
            u = (t * strokes + (0.5 if i % 2 else 0.0)) % 1.0
            if u < 0.55:
                # Gripping: dragged back along the ground, the tip curled in to hold.
                k = u / 0.55
                sw, up, curl = lerp(1.0, -1.0, k), 0.0, 1.0
            else:
                k = (u - 0.55) / 0.45
                sw, up, curl = lerp(-1.0, 1.0, ease(k)), math.sin(math.pi * k), 1.0 - math.sin(math.pi * k)
            sweep(i, "a", 18.0 * sw)
            lift(i, "a", 24.0 * up)
            lift(i, "b", 10.0 * up - 14.0 * curl)
            lift(i, "c", 6.0 * up - 22.0 * curl)
            sweep(i, "c", 6.0 * math.sin(2 * math.pi * u))
        return -1.0

    def idle(t):
        w = math.sin(2 * math.pi * t)
        sk.place_root(sk.h0["mantle"] + Vector((0.0, 0.0, 0.012 * w)), body_q(-2.0 * w, 0.0, 0.0))
        for i in arms:
            ph = i * 1.1
            for k, seg in enumerate(("a", "b", "c")):
                s = math.sin(2 * math.pi * t * 2.0 + ph + k * 0.9)
                lift(i, seg, (3.0 + 5.0 * k) * s)
                sweep(i, seg, (4.0 + 3.0 * k) * math.sin(2 * math.pi * t + ph * 0.7 + k))
        return -1.0

    def lunge(t):
        """Arms flung up and forward round the prey, then snapped shut. 0.6 s."""
        k = ease(min(1.0, t / 0.45))
        snap = ease(max(0.0, (t - 0.45) / 0.55))
        sk.place_root(sk.h0["mantle"] + Vector((0.0, -0.05 * k, 0.1 * k * (1.0 - snap))), body_q(-14.0 * k * (1.0 - snap), 0.0, 0.0))
        for i in arms:
            if info[i]["front"] > -0.2:
                lift(i, "a", 50.0 * k - 30.0 * snap)
                sweep(i, "a", 25.0 * k + 10.0 * snap)
                lift(i, "b", 10.0 * k - 45.0 * snap)
                lift(i, "c", -50.0 * snap)
            else:
                lift(i, "a", -6.0 * k)
                sweep(i, "a", -10.0 * k)
        return -1.0

    def recoil(t):
        """Struck: the mantle jerks up and back, every arm curls in, then it spreads again."""
        k = keyed([(0.0, {"a": 0.0}), (0.08, {"a": 1.0}), (0.3, {"a": 0.7}), (0.6, {"a": 0.0})], t * 0.6)["a"]
        sk.place_root(sk.h0["mantle"] + Vector((0.0, 0.06 * k, 0.07 * k)), body_q(-16.0 * k, 0.0, 0.0))
        for i in arms:
            lift(i, "a", 20.0 * k)
            lift(i, "b", -25.0 * k)
            lift(i, "c", -40.0 * k)
        return -1.0

    def burn(t):
        """Seared by the beam: reared up off the ground, every arm thrashing and curling."""
        w = math.sin(2 * math.pi * t)
        sk.place_root(sk.h0["mantle"] + Vector((0.0, 0.05, 0.1 + 0.02 * w)), body_q(-22.0 + 4.0 * w, 6.0 * math.sin(4 * math.pi * t), 0.0))
        for i in arms:
            ph = 2 * math.pi * (t * 2.0 + i * 0.17)
            lift(i, "a", 25.0 + 15.0 * math.sin(ph))
            sweep(i, "a", 15.0 * math.sin(ph * 1.3))
            lift(i, "b", -20.0 - 20.0 * math.sin(ph + 1.0))
            lift(i, "c", -35.0 - 25.0 * math.sin(ph + 2.0))
        return -1.0

    return [("idle", 2.0, idle, True), ("walk", 1.2, crawl, True), ("lunge", 0.6, lunge, False),
            ("stagger_back", 0.6, recoil, False), ("burn", 0.6, burn, True)], {}


# ---------------------------------------------------------------- the build

KEEPERS = ("callum_keeper", "hamish_keeper", "mairi_keeper", "ewan_keeper")


def humanoid_set(sk, kind):
    b = Body(sk)
    clips = []   # (name, seconds, pose, loop, frames)
    meta = {"clips": {}}

    def add(name, seconds, pose, loop, frames=None, **info):
        clips.append((name, seconds, pose, loop, frames))
        meta["clips"][name] = dict(info, loop=loop, length=seconds if frames is None else frames / FPS)

    if kind == "keeper":
        walk = Gait(b, 0.92, 0.6, 0.68, 0.012, 0.012, 0.12, strike=14.0, toe_off=32.0, sway=0.022, list_=3.0, yaw=6.0, lean=3.0)
        # Keepers move at 4.5 m/s, 6.5 sprinting: long-striding runs with short contact
        # and a real flight phase, so the clips' natural speeds match the game's.
        run = Gait(b, 0.62, 0.23, 0.9, 0.08, 0.05, 0.36, strike=4.0, toe_off=40.0, heel=0.08, toe=0.45, runner=True,
                   sway=0.012, list_=2.5, yaw=9.0, lean=12.0, kick=0.3)
        sprint = Gait(b, 0.54, 0.2, 1.0, 0.09, 0.055, 0.44, strike=2.0, toe_off=45.0, heel=0.06, toe=0.4, runner=True,
                      sway=0.01, list_=2.0, yaw=11.0, lean=17.0, kick=0.36)
        add("idle", 4.0, keeper_idle(b), True)
        add("walk", 1.0, keeper_cycle(b, walk), True, CYCLE_FRAMES, period=walk.period, speed=walk.speed)
        add("run", 1.0, keeper_cycle(b, run, run=True, chest_twist=10.0, head_pitch=6.0), True, CYCLE_FRAMES, period=run.period, speed=run.speed)
        add("sprint", 1.0, keeper_cycle(b, sprint, run=True, arms=1.3, chest_twist=12.0, head_pitch=8.0), True, CYCLE_FRAMES,
            period=sprint.period, speed=sprint.speed)
        add("swing", 0.55, keeper_swing(b), False)
        add("hammer", 0.34, keeper_hammer(b), True)
        add("pour", 0.9, keeper_pour(b), False)
        climb, rise = keeper_climb(b)
        add("climb", 1.2, climb, True, rise=rise)
        add("flare", 0.6, keeper_flare(b), False)
        add("hit", 0.45, hit_react(b, keeper_hit_arms), False)
        add("stagger_back", 0.8, stagger(b, True, 0.5, carry=keeper_carry), False, travel=0.5, slide=STAGGER_SLIDE)
        add("stagger_fwd", 0.8, stagger(b, False, 0.5, carry=keeper_carry), False, travel=0.5, slide=STAGGER_SLIDE)
        add("throw", 0.8, keeper_throw(b), False, release=THROW_RELEASE)
        add("revive", 0.8, kneel_work(b), True)
        # Keepers are quick about it: being floored shouldn't cost too long.
        gb, hb, tb = getup_back(b, slow=0.82)
        gf, hf, tf = getup_front(b, slow=0.85)
    elif kind == "bloated":
        walk = Gait(b, 1.5, 0.66, 0.45, 0.07, 0.03, 0.08, strike=6.0, toe_off=18.0, sway=0.06, list_=7.0, yaw=8.0, lean=12.0,
                    width=0.05, drag={"side": "R", "lift": 0.25, "toe": 18.0})
        add("idle", 3.2, bloated_idle(b), True)
        add("walk", 1.0, bloated_cycle(b, walk), True, CYCLE_FRAMES, period=walk.period, speed=walk.speed)
        add("bloat", 1.2, bloated_swell(b), False)
        add("burn", 0.9, burn_writhe(b), True)
        add("strike", 1.1, creature_strike(b, 0.9, 1.2), False)
        add("hit", 0.45, hit_react(b), False)
        add("stagger_back", 0.9, stagger(b, True, 0.35, 0.9, heavy=1.0), False, travel=0.35, slide=STAGGER_SLIDE)
        gb, hb, tb = getup_back(b, slow=1.35, heavy=1.0)
        gf, hf, tf = getup_front(b, slow=1.35, heavy=1.0)
    else:  # smotherer
        walk = Gait(b, 1.15, 0.62, 0.7, 0.1, 0.025, 0.14, strike=10.0, toe_off=28.0, sway=0.015, list_=3.0, yaw=7.0, lean=16.0)
        add("idle", 3.0, smotherer_idle(b), True)
        add("walk", 1.0, smotherer_cycle(b, walk), True, CYCLE_FRAMES, period=walk.period, speed=walk.speed)
        climb, rise = smotherer_climb(b)
        add("climb", 1.0, climb, True, rise=rise)
        add("smother", 2.5, smotherer_smother(b), True)
        add("strike", 0.9, creature_strike(b, 1.2, 1.0), False)
        add("hit", 0.45, hit_react(b), False)
        add("stagger_back", 0.8, stagger(b, True, 0.45), False, travel=0.45, slide=STAGGER_SLIDE)
        gb, hb, tb = getup_back(b, slow=1.1)
        gf, hf, tf = getup_front(b, slow=1.1)
    add("getup_back", tb, gb, False, hips=rig_space(hb))
    add("getup_front", tf, gf, False, hips=rig_space(hf))
    return clips, meta


def rig_space(v):
    """Blender model space to the game's rig space (as the markers are written)."""
    v = Vector(v)
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def build(name, rig):
    """Author every clip for this character on its rig. Returns the metadata for its
    .anims.json, or None if it has no clips."""
    sk = Skel(rig)
    if name in KEEPERS:
        clips, meta = humanoid_set(sk, "keeper")
    elif name in ("bloated", "smotherer"):
        clips, meta = humanoid_set(sk, name)
    elif name == "crab":
        cl, info = crab_clips(sk)
        clips = [(n, s, p, l, CYCLE_FRAMES if n == "walk" else None) for n, s, p, l in cl]
        meta = {"clips": {n: dict(info.get(n, {}), loop=l, length=(1.0 if n == "walk" else s)) for n, s, p, l in cl}}
        meta["clips"]["stagger_back"].update(travel=0.25, slide=STAGGER_SLIDE)
    elif name == "squid":
        cl, info = squid_clips(sk)
        clips = [(n, s, p, l, None) for n, s, p, l in cl]
        meta = {"clips": {n: dict(loop=l, length=s) for n, s, p, l in cl}}
        meta["clips"]["stagger_back"].update(travel=0.35, slide=STAGGER_SLIDE)
        meta["clips"]["walk"]["period"] = 1.2
        meta["clips"]["walk"]["speed"] = 2.2
    else:
        return None
    for cname, seconds, pose, loop, frames in clips:
        record(sk, cname, seconds, pose, loop, frames)
    if rig.animation_data:
        rig.animation_data.action = None
    sk.reset()
    return meta
