#InspectDR: Support for pan/zoom
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const PAN_STEPRATIO = 0.25 #Percentage of current extents
const ZOOM_STEPRATIO = 2.0 #How much to zoom in/out with mousewheel + keybindings


#==Drawing functions
===============================================================================#
function selectionbox_draw(ctx::CairoContext, selbb::BoundingBox, graphbb::BoundingBox, hallowed::Bool, vallowed::Bool)
	xmin = selbb.xmin; xmax = selbb.xmax
	ymin = selbb.ymin; ymax = selbb.ymax
	if !hallowed
		xmin = graphbb.xmin
		xmax = graphbb.xmax
	end
	if !vallowed
		ymin = graphbb.ymin
		ymax = graphbb.ymax
	end

	Cairo.save(ctx) #-----
	setlinestyle(ctx, LineStyle(:dash, 1.0, COLOR_BLACK))
	Cairo.rectangle(ctx, BoundingBox(xmin, xmax, ymin, ymax))
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----

	nothing
end

function selectionbox_draw(ctx::CairoContext, w::PlotWidget)
	if !w.sel.enabled; return; end
	graphbb = w.graphbblist[activestrip(w)]
	selectionbox_draw(ctx, w.sel.bb, graphbb, w.hallowed, w.vallowed)
end


#==Switching to h/v lock (or releasing both)
===============================================================================#
function locdir_h(pwidget::PlotWidget)
	pwidget.hallowed = true
	pwidget.vallowed = false
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function locdir_v(pwidget::PlotWidget)
	pwidget.hallowed = false
	pwidget.vallowed = true
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function locdir_any(pwidget::PlotWidget)
	pwidget.hallowed = true
	pwidget.vallowed = true
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end


#==Scale/position widget control
===============================================================================#
function scalectrl_enabled(pwidget::PlotWidget)
	return Gtk.GAccessor.sensitive(pwidget.w_xscale)
end
function scalectrl_enabled(pwidget::PlotWidget, v::Bool)
	Gtk.GAccessor.sensitive(pwidget.w_xscale, v)
	Gtk.GAccessor.sensitive(pwidget.w_xpos, v)
end
#Apply current scale/position scrollbar values to plot extents:
function scalectrl_apply(pwidget::PlotWidget)
	xscale = getproperty(pwidget.xscale, :value, Int)
	xpos = getproperty(pwidget.xpos, :value, Float64)

	const plot = pwidget.src
	const ixf = InputXfrm1D(plot.xscale)

	#Use transformed coordinate system:
	xext_full = read2axis(getxextents_full(plot), ixf)
	span = xext_full.max - xext_full.min
	center = (xext_full.max + xext_full.min) / 2
	vspan = span/xscale #Visible span
	xmin = center + span*xpos - vspan/2
	xmax = xmin + vspan

	#Update extents & redraw
	xext_new = PExtents1D(xmin, xmax)
	xext = merge(getxextents_axis(plot), xext_new)
	setxextents_axis(plot, xext)

	render(pwidget)
	Gtk.draw(pwidget.canvas)
end


#==Basic zoom control
===============================================================================#
#Zoom to bounding box (in device coordinates):
function zoom(pwidget::PlotWidget, bb::BoundingBox, istrip::Int)
	p1 = Point2D(bb.xmin, bb.ymin)
	p2 = Point2D(bb.xmax, bb.ymax)

	ext = getextents_axis(pwidget.src, istrip)
	xf = Transform2D(ext, pwidget.graphbblist[istrip])
	p1 = map2axis(xf, p1)
	p2 = map2axis(xf, p2)

	if pwidget.hallowed
		setxextents_axis(pwidget.src, PExtents1D(min(p1.x, p2.x), max(p1.x, p2.x)))
	end

	if pwidget.vallowed
		setyextents_axis(pwidget.src, PExtents1D(min(p1.y, p2.y), max(p1.y, p2.y)), istrip)
	end

	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end

#Zoom in/out @ point (pt in plot coordinates)
function zoom(pwidget::PlotWidget, ext::PExtents2D, pt::Point2D, ratio::Float64, istrip::Int)
	xspan = ext.xmax - ext.xmin
	yspan = ext.ymax - ext.ymin
	Δx = pt.x - ext.xmin
	Δy = pt.y - ext.ymin
	xmin = pt.x-ratio*Δx
	ymin = pt.y-ratio*Δy

	setxextents_axis(pwidget.src, PExtents1D(xmin, xmin + ratio*xspan))
	setyextents_axis(pwidget.src, PExtents1D(ymin, ymin + ratio*yspan), istrip)

	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end

#Zoom in/out, centered on current extents
function zoom(pwidget::PlotWidget, ratio::Float64, istrip::Int)
	ext = getextents_axis(pwidget.src, istrip)
	pt = Point2D((ext.xmin+ext.xmax)/2, (ext.ymin+ext.ymax)/2)
	zoom(pwidget, ext, pt, ratio, istrip)
end
zoom_out(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, stepratio, activestrip(pwidget))
zoom_in(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, 1/stepratio, activestrip(pwidget))

#Zoom in/out around specified device coordinates:
function zoom(pwidget::PlotWidget, x::Float64, y::Float64, ratio::Float64, istrip::Int)
	pt = Point2D(x, y)
	ext = getextents_axis(pwidget.src, istrip)
	xf = Transform2D(ext, pwidget.graphbblist[istrip])
	pt = map2axis(xf, pt)
	zoom(pwidget, ext, pt, ratio, istrip)
end
zoom_out(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, x, y, stepratio, activestrip(pwidget))
zoom_in(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, x, y, 1/stepratio, activestrip(pwidget))

function zoom_xfull(pwidget::PlotWidget)
	#TODO
end
function zoom_full(pwidget::PlotWidget, hallowed::Bool, vallowed::Bool, istrip::Int)
	#Reset desired extents:
	if hallowed
		setxextents(pwidget.src, PExtents1D())
	end
	if vallowed
		setyextents(pwidget.src, PExtents1D(), istrip)
	end

	if hallowed
		scalectrl_enabled(pwidget, false) #Suppress updates from setproperty!
		setproperty!(pwidget.xscale, :value, Int(1))
		setproperty!(pwidget.xpos, :value, Float64(0))
		scalectrl_enabled(pwidget, true)
		scalectrl_apply(pwidget)
	else
		render(pwidget)
		Gtk.draw(pwidget.canvas)
	end
end
zoom_full(pwidget::PlotWidget, hallowed::Bool=true, vallowed::Bool=true) =
	zoom_full(pwidget, hallowed, vallowed, activestrip(pwidget))
zoom_hfull(pwidget::PlotWidget) = zoom_full(pwidget, true, false)
zoom_vfull(pwidget::PlotWidget) = zoom_full(pwidget, false, true)


#==Box-zoom control
===============================================================================#
function boxzoom_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	locdir_any(pwidget)
	pwidget.sel.enabled = true
	pwidget.sel.istrip = activestrip(pwidget)
	pwidget.sel.bb = BoundingBox(x, x, y, y)
end
function boxzoom_cancel(pwidget::PlotWidget)
	pwidget.sel.enabled = false
	Gtk.draw(pwidget.canvas)
end
function boxzoom_complete(pwidget::PlotWidget, x::Float64, y::Float64)
	pwidget.sel.enabled = false
	bb = pwidget.sel.bb
	pwidget.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)
	zoom(pwidget, pwidget.sel.bb, pwidget.sel.istrip)
end
#Set end point of boxzoom area:
function boxzoom_setend(pwidget::PlotWidget, x::Float64, y::Float64)
	bb = pwidget.sel.bb
	pwidget.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)	
	Gtk.draw(pwidget.canvas)
end


#==Basic pan control
===============================================================================#
function pan_xratio(pwidget::PlotWidget, panstepratio::Float64)
	xext = getxextents_axis(pwidget.src)
	panstep = panstepratio*(xext.max-xext.min)
	setxextents_axis(pwidget.src,
		PExtents1D(xext.min+panstep, xext.max+panstep))
	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function pan_yratio(pwidget::PlotWidget, panstepratio::Float64, istrip::Int)
	yext = getyextents_axis(pwidget.src, istrip)
	panstep = panstepratio*(yext.max-yext.min)
	setyextents_axis(pwidget.src,
		PExtents1D(yext.min+panstep, yext.max+panstep), istrip)
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
pan_yratio(pwidget::PlotWidget, panstepratio::Float64) =
	pan_yratio(pwidget, panstepratio, activestrip(pwidget))

pan_left(pwidget::PlotWidget) = pan_xratio(pwidget, -PAN_STEPRATIO)
pan_right(pwidget::PlotWidget) = pan_xratio(pwidget, PAN_STEPRATIO)
pan_up(pwidget::PlotWidget) = pan_yratio(pwidget, PAN_STEPRATIO)
pan_down(pwidget::PlotWidget) = pan_yratio(pwidget, -PAN_STEPRATIO)


#==Mouse-pan control
===============================================================================#
#Δy/Δy: in device coordinates
function mousepan_delta(pwidget::PlotWidget, ext::PExtents2D, Δx::Float64, Δy::Float64, istrip::Int)
	#Convert to plot coordinates:
	xf = Transform2D(ext, pwidget.graphbblist[istrip])
	Δvec = map2axis_vec(xf, Point2D(-Δx, -Δy))

	setextents_axis(pwidget.src, ext, istrip) #Restore original extents before overwriting

	if pwidget.hallowed
		setxextents_axis(pwidget.src, PExtents1D(ext.xmin+Δvec.x, ext.xmax+Δvec.x))
	end
	if pwidget.vallowed
		setyextents_axis(pwidget.src, PExtents1D(ext.ymin+Δvec.y, ext.ymax+Δvec.y), istrip)
	end

	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function mousepan_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	locdir_any(pwidget)
	pwidget.sel.bb = BoundingBox(x, x, y, y) #Tracks start/end pos
	pwidget.sel.istrip = istrip = activestrip(pwidget)
	pwidget.sel.ext_start = getextents_axis(pwidget.src, istrip)
end
function mousepan_cancel(pwidget::PlotWidget)
	mousepan_delta(pwidget, pwidget.sel.ext_start, 0.0, 0.0, pwidget.sel.istrip)
end
function mousepan_complete(pwidget::PlotWidget, x::Float64, y::Float64)
	#Already panned.
end
#Set new point of mousepan operation:
function mousepan_move(pwidget::PlotWidget, x::Float64, y::Float64)
	bb = pwidget.sel.bb
	bb = BoundingBox(bb.xmin, x, bb.ymin, y)
	pwidget.sel.bb = bb
	Δx = bb.xmax-bb.xmin; Δy = bb.ymax-bb.ymin
	mousepan_delta(pwidget, pwidget.sel.ext_start, Δx, Δy, pwidget.sel.istrip)
end


#Last line
