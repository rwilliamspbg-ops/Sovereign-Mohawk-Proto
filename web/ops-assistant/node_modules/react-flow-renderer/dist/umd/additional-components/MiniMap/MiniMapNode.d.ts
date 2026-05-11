import React, { CSSProperties } from 'react';
interface MiniMapNodeProps {
    x: number;
    y: number;
    width: number;
    height: number;
    borderRadius: number;
    className: string;
    color: string;
    shapeRendering: string;
    strokeColor: string;
    strokeWidth: number;
    style?: CSSProperties;
}
declare const _default: React.MemoExoticComponent<{
    ({ x, y, width, height, style, color, strokeColor, strokeWidth, className, borderRadius, shapeRendering, }: MiniMapNodeProps): JSX.Element;
    displayName: string;
}>;
export default _default;
