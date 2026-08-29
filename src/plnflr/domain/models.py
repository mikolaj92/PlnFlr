"""Floor-layout domain types. A room is a polygon with holes."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True, slots=True)
class Vertex:
    x_mm: int
    y_mm: int


@dataclass(frozen=True, slots=True)
class Ring:
    vertices: tuple[Vertex, ...]

    def __post_init__(self) -> None:
        if len(self.vertices) < 3:
            raise ValueError("ring needs ≥ 3 vertices")


@dataclass(frozen=True, slots=True)
class Room:
    outer: Ring
    holes: tuple[Ring, ...] = ()


@dataclass(frozen=True, slots=True)
class PlankSpec:
    length_mm: int
    width_mm: int
    boards_per_pack: int | None = None


@dataclass(frozen=True, slots=True)
class TileSpec:
    length_mm: int
    width_mm: int
    grout_mm: int = 3
    tiles_per_pack: int | None = None


@dataclass(frozen=True, slots=True)
class Zone:
    kind: Literal["plank", "tile"]
    plank: PlankSpec | None = None
    tile: TileSpec | None = None
    angle_deg: int | None = None
    label: str | None = None


@dataclass(frozen=True, slots=True)
class LayoutRules:
    expansion_mm: int | None = None
    expansion_min_mm: int = 10
    expansion_per_m_mm: str = "1.5"
    min_row_width_mm: int = 50
    min_end_length_mm: int = 300
    min_stagger_mm: int = 300
    stagger: Literal["third", "half"] = "third"
    direction: Literal["along_long", "along_short", "along_x", "along_y"] = "along_long"
    min_tile_cut_mm: int = 30
    intermediate_joint_mm: int = 8000
    angle_deg: int = 0


@dataclass(frozen=True, slots=True)
class Piece:
    piece_id: str
    row_index: int
    geometry: tuple[Vertex, ...]
    kind: Literal["full", "start_cut", "end_cut", "rip", "clip", "tile_full", "tile_cut"]
    source_board: int
    install_order: int
    length_mm: int
    width_mm: int
    zone_index: int = 0


@dataclass(frozen=True, slots=True)
class Warning:
    code: str
    message_pl: str


@dataclass(frozen=True, slots=True)
class BillOfMaterials:
    pieces: int
    full_boards: int
    packs: int | None
    area_net_mm2: int
    area_bought_mm2: int
    waste_pct: str
    label: str = ""
    kind: Literal["plank", "tile", "mixed"] = "plank"


@dataclass(frozen=True, slots=True)
class LayoutPlan:
    room: Room
    gap_mm: int
    inset: Room
    direction: Literal["along_x", "along_y"]
    pieces: tuple[Piece, ...]
    bom: BillOfMaterials
    warnings: tuple[Warning, ...]
    rationale_pl: str
    rows_instruction_pl: tuple[str, ...]
    angle_deg: int = 0
    split_axis: Literal["x", "y"] | None = None
    split_at_mm: int | None = None
    boms: tuple[BillOfMaterials, ...] = ()
    divider: tuple[Vertex, Vertex] | None = None
