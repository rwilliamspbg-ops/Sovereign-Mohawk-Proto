import React from 'react';
import { EdgeProps, Position } from '../../types';
export interface GetBezierPathParams {
    sourceX: number;
    sourceY: number;
    sourcePosition?: Position;
    targetX: number;
    targetY: number;
    targetPosition?: Position;
    curvature?: number;
}
export declare function getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition, curvature, }: GetBezierPathParams): string;
export declare function getBezierCenter({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition, curvature, }: GetBezierPathParams): [number, number, number, number];
declare const _default: React.MemoExoticComponent<({ sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, label, labelStyle, labelShowBg, labelBgStyle, labelBgPadding, labelBgBorderRadius, style, markerEnd, markerStart, curvature, }: EdgeProps) => JSX.Element>;
export default _default;
