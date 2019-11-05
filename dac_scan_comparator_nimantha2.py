#!/bin/env python                                                                                                

from gempython.gemplotting.utils.anautilities import make3x8Canvas
from gempython.gemplotting.mapping.chamberInfo import chamber_vfatPos2PadIdx
from gempython.gemplotting.utils.anautilities import getCyclicColor

import os
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("chambername", help="chambername to be used in the form GE11-X-S-SITE-ID")
parser.add_argument("-b","--batchmode", help="run in batch mode and not display any graphics" ,action="store_true")
parser.add_argument("-s","--scandates",default=[],nargs='+',help="scandates to be compared with a space between each other")
parser.add_argument("-i","--inputfile",help="if comparison is done between two chambers, tab delimited text file with chamber name and scandate in eachrow ")
args = parser.parse_args()

import ROOT as r
if args.batchmode:
    r.gROOT.SetBatch(True)

# scandates = ["2019.07.04.18.15","2019.07.04.19.01","2019.07.04.19.21","2019.07.04.20.38","2019.07.04.22.39","2019.07.04.23.04"]
chambername = args.chambername # "GE11-X-S-CERN-0009"
anatype = "dacScans"
dacnames = ["CFG_BIAS_CFD_DAC_1","CFG_BIAS_CFD_DAC_2","CFG_BIAS_PRE_I_BIT","CFG_BIAS_PRE_I_BLCC","CFG_BIAS_PRE_I_BSF","CFG_BIAS_PRE_VREF","CFG_BIAS_SD_I_BDIFF","CFG_BIAS_SD_I_BFCAS","CFG_BIAS_SD_I_BSF","CFG_BIAS_SH_I_BDIFF","CFG_BIAS_SH_I_BFCAS","CFG_HYST"]#,"CFG_CAL_DAC","CFG_THR_ARM_DAC","CFG_THR_ZCC_DAC","CFG_VREF_ADC"]

if (anatype=="dacScans"):
	rootfile="DACFitData.root"

if args.inputfile is not None:
	openfile = open(args.inputfile, "r")
	cnameList=[]
	scandateList=[]
	for line in openfile:
		cname,scandate = line.split("\t")
		scandate=scandate.rstrip('\n')
		cnameList.append(cname)
		scandateList.append(scandate)
	
	for j in range(len(dacnames)):
		canv = r.TCanvas('scan','scan',500*8,500*3)
		canv.Divide(8,3)
		leg = r.TLegend(0.1,0.6,0.48,0.9)
		for i in range(len(cnameList)):
			
			f = r.TFile.Open('/data/bigdisk/GEM-Data-Taking/GE11_QC8/'+str(cnameList[i])+'/'+anatype+'/'+str(scandateList[i])+'/'+rootfile)
			g = [0] * 24
			for x in range(24):
				canv.cd(chamber_vfatPos2PadIdx[x])
            #canv.BuildLegend()
				g[x] = r.TGraphErrors()
				g[x] = f.Get('VFAT'+str(x)+'/'+dacnames[j]+'/g_VFAT'+str(x)+'_DACvsADC_'+dacnames[j])
				if (i==0):
					g[x].SetLineColor(getCyclicColor(i))
					g[x].Draw()
				else:
					g[x].SetLineColor(getCyclicColor(i))
					g[x].Draw("SAME")
        
        #make3x8Canvas(scandates[i],g,'',None,'',None)
        #print (g)  
			leg.AddEntry(g[0],cnameList[i],"lep")
		leg.Draw()
		canv.Update()
		canv.SaveAs("/data/bigdisk/GEM-Data-Taking/GE11_QC8/"+chambername+"/"+dacnames[j]+".png")
	



else:
	for j in range(len(dacnames)):

		canv = r.TCanvas('scan','scan',500*8,500*3)
		canv.Divide(8,3)
		leg = r.TLegend(0.1,0.6,0.48,0.9)
#		for i in range(len(args.scandates)):
		for i in range(len(args.scandates)):            
			f = r.TFile.Open('/data/bigdisk/GEM-Data-Taking/GE11_QC8/'+chambername+'/'+anatype+'/'+str(args.scandates[i])+'/'+rootfile)
			g = [0] * 24
			for x in range(24):
				canv.cd(chamber_vfatPos2PadIdx[x])
                #canv.BuildLegend()
				g[x] = r.TGraphErrors()
				g[x] = f.Get('VFAT'+str(x)+'/'+dacnames[j]+'/g_VFAT'+str(x)+'_DACvsADC_'+dacnames[j])
				if (i==0):
					g[x].SetLineColor(getCyclicColor(i))
					g[x].Draw()
				else:
					g[x].SetLineColor(getCyclicColor(i))
					g[x].Draw("SAME")
            	
            #make3x8Canvas(scandates[i],g,'',None,'',None)
            #print (g)	
			leg.AddEntry(g[0],args.scandates[i],"lep")
		leg.Draw()
		canv.Update()

        #canv.BuildLegend()	
		canv.SaveAs("/data/bigdisk/GEM-Data-Taking/GE11_QC8/"+chambername+"/"+dacnames[j]+".png")
	


print ("Execution Complete")
