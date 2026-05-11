import { EdgeTypes, EdgeTypesWrapped, HandleElement, NodeHandleBounds, NodeInternals, Position, Rect, Transform, XYPosition } from '../../types';
export declare type CreateEdgeTypes = (edgeTypes: EdgeTypes) => EdgeTypesWrapped;
export declare function createEdgeTypes(edgeTypes: EdgeTypes): EdgeTypesWrapped;
export declare function getHandlePosition(position: Position, nodeRect: Rect, handle?: any | null): XYPosition;
export declare function getHandle(bounds: HandleElement[], handleId: string | null): HandleElement | null;
interface EdgePositions {
    sourceX: number;
    sourceY: number;
    targetX: number;
    targetY: number;
}
export declare const getEdgePositions: (sourceNodeRect: Rect, sourceHandle: HandleElement | unknown, sourcePosition: Position, targetNodeRect: Rect, targetHandle: HandleElement | unknown, targetPosition: Position) => EdgePositions;
interface IsEdgeVisibleParams {
    sourcePos: XYPosition;
    targetPos: XYPosition;
    sourceWidth: number;
    sourceHeight: number;
    targetWidth: number;
    targetHeight: number;
    width: number;
    height: number;
    transform: Transform;
}
export declare function isEdgeVisible({ sourcePos, targetPos, sourceWidth, sourceHeight, targetWidth, targetHeight, width, height, transform, }: IsEdgeVisibleParams): boolean;
export declare function getNodeData(nodeInternals: NodeInternals, nodeId: string): [Rect, NodeHandleBounds | null, boolean];
export {};
