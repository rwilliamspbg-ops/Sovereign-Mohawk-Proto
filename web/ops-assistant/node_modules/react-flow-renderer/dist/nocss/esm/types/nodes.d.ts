import { CSSProperties, MouseEvent as ReactMouseEvent } from 'react';
import { XYPosition, Position, CoordinateExtent } from './utils';
import { HandleElement } from './handles';
import { internalsSymbol } from '../utils';
export interface Node<T = any> {
    id: string;
    position: XYPosition;
    data: T;
    type?: string;
    style?: CSSProperties;
    className?: string;
    targetPosition?: Position;
    sourcePosition?: Position;
    hidden?: boolean;
    selected?: boolean;
    dragging?: boolean;
    draggable?: boolean;
    selectable?: boolean;
    connectable?: boolean;
    dragHandle?: string;
    width?: number | null;
    height?: number | null;
    parentNode?: string;
    zIndex?: number;
    extent?: 'parent' | CoordinateExtent;
    expandParent?: boolean;
    positionAbsolute?: XYPosition;
    [internalsSymbol]?: {
        z?: number;
        handleBounds?: NodeHandleBounds;
        isParent?: boolean;
    };
}
export interface NodeProps<T = any> {
    id: string;
    type: string;
    data: T;
    selected: boolean;
    isConnectable: boolean;
    xPos: number;
    yPos: number;
    dragging: boolean;
    zIndex: number;
    targetPosition?: Position;
    sourcePosition?: Position;
    dragHandle?: string;
}
export declare type NodeMouseHandler = (event: ReactMouseEvent, node: Node) => void;
export declare type NodeDragHandler = (event: ReactMouseEvent, node: Node, nodes: Node[]) => void;
export declare type SelectionDragHandler = (event: ReactMouseEvent, nodes: Node[]) => void;
export interface WrapNodeProps<T = any> {
    id: string;
    type: string;
    data: T;
    selected: boolean;
    isConnectable: boolean;
    xPos: number;
    yPos: number;
    initialized: boolean;
    isSelectable: boolean;
    isDraggable: boolean;
    selectNodesOnDrag: boolean;
    onClick?: NodeMouseHandler;
    onDoubleClick?: NodeMouseHandler;
    onMouseEnter?: NodeMouseHandler;
    onMouseMove?: NodeMouseHandler;
    onMouseLeave?: NodeMouseHandler;
    onContextMenu?: NodeMouseHandler;
    style?: CSSProperties;
    className?: string;
    sourcePosition: Position;
    targetPosition: Position;
    hidden?: boolean;
    resizeObserver: ResizeObserver | null;
    dragHandle?: string;
    zIndex: number;
    isParent: boolean;
    noPanClassName: string;
    noDragClassName: string;
}
export declare type NodeHandleBounds = {
    source: HandleElement[] | null;
    target: HandleElement[] | null;
};
export declare type NodeDimensionUpdate = {
    id: string;
    nodeElement: HTMLDivElement;
    forceUpdate?: boolean;
};
export declare type NodeInternals = Map<string, Node>;
export declare type NodeBounds = XYPosition & {
    width: number | null;
    height: number | null;
};
export declare type NodeDragItem = {
    id: string;
    position: XYPosition;
    positionAbsolute: XYPosition;
    distance: XYPosition;
    width?: number | null;
    height?: number | null;
    extent?: 'parent' | CoordinateExtent;
    parentNode?: string;
    dragging?: boolean;
};
