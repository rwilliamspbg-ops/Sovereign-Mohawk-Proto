import { MouseEvent as ReactMouseEvent } from 'react';
import { GetState } from 'zustand';
import { Edge, MarkerType, Position, ReactFlowState } from '../../types';
export declare const getMarkerEnd: (markerType?: MarkerType, markerEndId?: string) => string;
export interface GetCenterParams {
    sourceX: number;
    sourceY: number;
    targetX: number;
    targetY: number;
    sourcePosition?: Position;
    targetPosition?: Position;
}
export declare const getCenter: ({ sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, }: GetCenterParams) => [number, number, number, number];
export declare function getMouseHandler(id: string, getState: GetState<ReactFlowState>, handler?: (event: ReactMouseEvent<SVGGElement, MouseEvent>, edge: Edge) => void): ((event: ReactMouseEvent<SVGGElement, MouseEvent>) => void) | undefined;
